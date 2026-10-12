extends SceneTree
var scene: Node3D
class InputProbe extends Node:
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed: print("Route key: ",event.as_text())
var diagnostic_mouse := -1
func trace_mouse() -> void:
	if Input.mouse_mode != diagnostic_mouse:
		diagnostic_mouse = Input.mouse_mode
		print("Route mouse transition: ",{"frame":Engine.get_process_frames(),"mode":diagnostic_mouse,"focus":root.has_focus(),"scene":current_scene.name if current_scene!=null else "none","nodes":root.get_children().map(func(n): return n.name)})
var visited: Array = []
var extended := false
var return_wax := false
var earned_checkpoint := false
var broken_route := "--broken-sword" in OS.get_cmdline_user_args()
var offers_route := "--julian-offers" in OS.get_cmdline_user_args()
var speech_route := "--rune-speech" in OS.get_cmdline_user_args()
var stone_route := "--ancient-stone" in OS.get_cmdline_user_args()
var spell_route := "--starting-spells" in OS.get_cmdline_user_args()
var cave_chain := "--earned-cave-chain" in OS.get_cmdline_user_args()
var earned_input := ""
func chain_save(path: String) -> String:
	if broken_route: return path.replace("act1_","act1_broken_")
	if "--weapon-shop" in OS.get_cmdline_user_args(): return path.replace("act1_","act1_shop_")
	if offers_route: return path.replace("act1_","act1_magic_speech_" if "runes_monastery_return" in path else "act1_magic_offers_")
	if speech_route and "wax_upper_return" not in path: return path.replace("act1_","act1_magic_speech_")
	if stone_route and "wax_upper_return" not in path: return path.replace("act1_","act1_magic_stone_")
	return path.replace("act1_","act1_magic_") if spell_route else (path.replace("act1_","act1_cave_") if cave_chain else path)
func chain_proof(path: String) -> String:
	if broken_route: return path.replace("res://docs/","res://docs/broken-")
	if "--weapon-shop" in OS.get_cmdline_user_args(): return path.replace("res://docs/","res://docs/shop-")
	if offers_route: return path.replace("res://docs/","res://docs/magic-speech-" if "hive-earned-rune-return" in path else "res://docs/magic-offers-")
	if speech_route and "hive-wax-return-checks" not in path: return path.replace("res://docs/","res://docs/magic-speech-")
	if stone_route and "hive-wax-return-checks" not in path: return path.replace("res://docs/","res://docs/magic-stone-")
	return path.replace("res://docs/","res://docs/magic-") if spell_route else (path.replace("res://docs/","res://docs/cave-") if cave_chain else path)
func engage_guardians() -> void:
	if not cave_chain or not scene.has_node("Warriors"): return
	var guards = scene.get_node("Warriors")
	if guards.health <= 0:
		fail("Player died during earned Hive route")
		return
	for id in scene.return_population.bodies:
		var body = scene.return_population.bodies[id]
		if body.collision_layer == 0 or scene.camera.global_position.distance_to(body.global_position) >= 94: continue
		if not guards.clear_path(body.global_position): continue
		var original: Transform3D = scene.camera.global_transform
		scene.camera.look_at(body.global_position)
		scene.starting_magic.select_spell("spark")
		if not scene.starting_magic.protected() and scene.starting_magic.cast(5): print("Return route cast protection near warrior ",id)
		if guards.strike(): print("Return route struck warrior ",id)
		scene.camera.global_transform = original
		break
	for enemy in range(2):
		var target: Vector3 = guards.POSITIONS[enemy]+Vector3(0,35,0)
		if guards.enemies[enemy] > 0 and scene.camera.global_position.distance_to(target)<90 and guards.clear_path(target):
			var original: Transform3D = scene.camera.global_transform
			scene.camera.look_at(target)
			guards.strike()
			scene.camera.global_transform = original
func tick_curse(delta: float) -> void:
	engage_guardians()
	if extended:
		scene.hive_curse.advance(delta)
		scene.curse.advance(delta)
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
var sidestep_frames := 0
var sidestep_sign := 1.0
func move_to(target: Vector2, sprint := false, limit := 900) -> bool:
	for step in range(limit):
		await physics_frame
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if scene.interface_hud.cursor_active or scene.runes.active() or paused:
				return fail("Route attempted movement through a modal interface")
			# The manual movement driver must obey the same capture requirement as W.
			# Capture was lost after rollback in rendered tests; use the ordinary click to resume.
			root.grab_focus()
			var click := InputEventMouseButton.new()
			click.button_index=MOUSE_BUTTON_LEFT
			click.position=Vector2(640,360)
			click.global_position=click.position
			click.pressed=true
			# Use the production world callback, like this driver's E interactions;
			# synthetic viewport mouse delivery is unreliable in this display session.
			scene._unhandled_input(click)
			print("Route resumed through world mouse handler; capture=",Input.mouse_mode)
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return fail("World mouse handler did not restore game input")
		if scene.resets != 0 or scene.flying or (not extended and scene.player_form != 0):
			return fail("Route reset, entered flight or changed supplied human form (resets=%d flying=%s form=%d extended=%s health=%d)" % [scene.resets,scene.flying,scene.player_form,extended,scene.get_node("Warriors").health])
		var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
		if offset.length()<2.0 and scene.player.is_on_floor(): return true
		var delta: float = scene.player.get_physics_process_delta_time()
		var speed := 120.0 if sprint else 80.0
		var direction := offset.normalized()*minf(1.0,offset.length()/(speed*delta))
		# Live return warriors pursue at55; a player sidesteps one that blocks the path.
		if sidestep_frames > 0:
			sidestep_frames -= 1
			direction = Vector2(-offset.y,offset.x).normalized()*sidestep_sign
			# Never sidestep off a ledge: without floor ahead, hold position instead.
			var probe: Vector3 = scene.player.global_position+Vector3(direction.x,0,direction.y)*24
			var down := PhysicsRayQueryParameters3D.create(probe,probe-Vector3(0,float(preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET)+12,0),1,[scene.player.get_rid()])
			if scene.player.get_world_3d().direct_space_state.intersect_ray(down).is_empty():
				sidestep_sign = -sidestep_sign
				direction = -direction
				probe = scene.player.global_position+Vector3(direction.x,0,direction.y)*24
				down = PhysicsRayQueryParameters3D.create(probe,probe-Vector3(0,float(preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET)+12,0),1,[scene.player.get_rid()])
				if scene.player.get_world_3d().direct_space_state.intersect_ray(down).is_empty(): direction = Vector2.ZERO
		else:
			for index in range(scene.player.get_slide_collision_count()):
				var hit = scene.player.get_slide_collision(index)
				var body = hit.get_collider()
				if body != null and body.has_meta("hive_return_actor") and hit.get_normal().y < 0.7:
					# A warrior standing on a steering waypoint: close enough counts as reached.
					if offset.length() < 20.0 and scene.player.is_on_floor(): return true
					sidestep_frames = 40
					sidestep_sign = 1.0 if (Vector2(-offset.y,offset.x)).dot(Vector2(hit.get_normal().x,hit.get_normal().z)) >= 0 else -1.0
					print("Sidestepping return warrior ",body.get_meta("hive_return_actor")," player=",scene.player.position," target=",target," enemy=",body.position," form=",scene.player_form," health=",scene.get_node("Warriors").health," magic=",scene.starting_magic.magic_state())
					break
		scene.move_grounded(Vector3(direction.x,0,direction.y),delta,sprint)
		tick_curse(delta)
	for index in range(scene.player.get_slide_collision_count()):
		var hit = scene.player.get_slide_collision(index)
		print("Blocked contact=",hit.get_position()," normal=",hit.get_normal()," collider=",hit.get_collider().get_path() if hit.get_collider() else "?")
	return fail("Route blocked toward %s at %s" % [target,scene.player.position])
func run() -> void:
	if "--input-diagnostic" in OS.get_cmdline_user_args():
		process_frame.connect(trace_mouse)
		root.add_child(InputProbe.new())
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	if cave_chain: current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	for frame in range(3): await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(cave_chain)
	# Supplied start only. Lower landing and passage approach must be walked.
	earned_checkpoint = cave_chain or "--earned-return" in OS.get_cmdline_user_args()
	if earned_checkpoint:
		earned_input = chain_save("user://tests/act1_flute_hive_return.json")
		if cave_chain:
			var proof = JSON.parse_string(FileAccess.get_file_as_string("res://docs/broken-earned-flute-return-walk-checks.json" if broken_route else "res://docs/magic-earned-flute-return-walk-checks.json" if spell_route else "res://docs/cave-earned-flute-return-walk-checks.json"))
			if FileAccess.get_sha256(earned_input) != proof.output_sha256:
				fail("Cave-derived flute save does not match proof")
				return
		if not scene.quickload(earned_input).is_empty():
			fail("Earned-flute return checkpoint unavailable")
			return
		scene.set_physics_process(false)
	else:
		scene.player.position = Vector3(-1066.5,-203,-8310.25) if extended else Vector3(-2564.5,-203,-7614.5)
	for tick in range(10):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	if extended:
		if not await move_to(Vector2(-1041.5,-8184.75)): return
		if not scene.hive_curse.checkpoint.enabled:
			fail("Source region392 did not enable curse")
			return
		var upper: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_curse_lift_route.json"))
		for point in upper.points:
			if not await move_to(Vector2(point[0],point[1])): return
		if not await move_to(Vector2(-2355,-7614)): return
		if not scene.request_jump():
			fail("Cannot jump onto platform")
			return
		if not await move_to(Vector2(-2510,-7614),true): return
		if not await move_to(Vector2(-2564.5,-7614.5)): return
	for stop in range(1,6):
		var direction: Vector3 = scene.elevator.aim_point(125)-scene.camera.global_position
		scene.player.rotation.y = atan2(-direction.x,-direction.z)
		scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
		if not scene.elevator.interact():
			fail("Cannot select lift stop")
			return
		for tick in range(150):
			await physics_frame
			scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
			tick_curse(scene.player.get_physics_process_delta_time())
	if not await move_to(Vector2(-2624,-7565)): return
	if not scene.request_jump():
		fail("Cannot jump from lower platform")
		return
	if not await move_to(Vector2(-2714,-7464),true,200): return
	print("Lower landing reached: ",scene.player.position)
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_lift_wax_route.json"))
	for index in range(route.points.size()):
		if index == 16:
			if not await move_to(Vector2(-3710,-7110)): return
			if not scene.request_jump():
				fail("Cannot jump wax approach ledge")
				return
			if not await move_to(Vector2(-3750,-7110)): return
			continue
		var point: Array = route.points[index]
		if not await move_to(Vector2(point[0],point[1])): return
		visited.append({"portal":index,"region":route.regions[index],"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z]})
		print("Reached portal ",index," region ",route.regions[index]," at ",scene.player.position)
	if extended:
		var save_path := "user://tests/hive_curse_walk.json"
		var save_error: String = scene.quicksave(save_path)
		if not save_error.is_empty():
			fail("Curse countdown save failed: "+save_error+" "+str(scene.hive_curse.checkpoint))
			return
		var saved: Dictionary = scene.hive_curse.checkpoint.duplicate(true)
		scene.hive_curse.advance(1.0)
		print("Before curse rollback mouse=",Input.mouse_mode)
		if not scene.quickload(save_path).is_empty() or scene.hive_curse.checkpoint != saved:
			fail("Curse countdown rollback failed")
			return
		print("After curse rollback mouse=",Input.mouse_mode)
		scene.set_physics_process(false)
		for tick in range(20000):
			await physics_frame
			var delta: float = scene.player.get_physics_process_delta_time()
			scene.move_grounded(Vector3.ZERO,delta)
			tick_curse(delta)
			if scene.player_form == 2: break
		if scene.player_form != 2:
			fail("Source-admitted timer did not produce lizard")
			return
		for point in [Vector2(-3813.25,-6990.5),Vector2(-3799,-6974.75),Vector2(-3782.5,-6957),Vector2(-3768,-6948.25),Vector2(-3750,-6945.5)]:
			if not await move_to(point): return
		var direction: Vector3 = scene.wax.aim_point()-scene.camera.global_position
		scene.player.rotation.y = atan2(-direction.x,-direction.z)
		scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
		if not scene.wax.collect():
			var sight := PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.wax.aim_point(),1,[scene.player.get_rid()])
			sight.hit_from_inside = true
			print("Wax pickup diagnostic: ",{"player":scene.player.position,"camera":scene.camera.global_position,"target":scene.wax.aim_point(),"form":scene.player_form,"mouse":Input.mouse_mode,"cursor":scene.interface_hud.cursor_active,"collected":scene.wax.collected,"ray":scene.get_world_3d().direct_space_state.intersect_ray(sight)})
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tmp/wax_pickup_failure.png")
			fail("Natural lizard could not collect wax")
			return
		if not scene.quicksave(save_path).is_empty() or not scene.quickload(save_path).is_empty():
			fail("Active Hive transformation/wax save failed")
			return
		var handoff: Dictionary = scene.area_handoff()
		var invalid := handoff.duplicate(true)
		invalid.quests.hive_curse.remaining = -1
		if scene.apply_area_handoff(invalid).is_empty() or scene.area_handoff() != handoff:
			fail("Malformed curse save changed live state")
			return
		var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
		root.add_child(jungle)
		await process_frame
		await process_frame
		if not jungle.apply_area_handoff(handoff).is_empty() or jungle.area_handoff().quests.hive_curse != handoff.quests.hive_curse:
			fail("Jungle did not preserve Hive timer")
			return
		jungle.free()
		DirAccess.remove_absolute(save_path)
		print("PASS: source gate admission, approach, lift descent, timed lizard, crawlspace wax pickup and saves without form/position injection")
	if return_wax:
		scene.set_physics_process(false)
		for point in [Vector2(-3768,-6948.25),Vector2(-3782.5,-6957),Vector2(-3799,-6974.75),Vector2(-3813.25,-6990.5),Vector2(-3839.75,-7015.25)]:
			if not await move_to(point): return
		for index in range(route.points.size()-2,-1,-1):
			if index == 16:
				if not await move_to(Vector2(-3750,-7110)): return
				if not await move_to(Vector2(-3710,-7110)): return
				continue
			var point: Array = route.points[index]
			if not await move_to(Vector2(point[0],point[1])): return
		if not await move_to(Vector2(-2714,-7464)): return
		if not scene.request_jump():
			fail("Cannot jump back onto lower platform")
			return
		if not await move_to(Vector2(-2614,-7560),true): return
		if not await move_to(Vector2(-2564.5,-7614.5)): return
		for stop in [6,7,0]:
			var direction: Vector3 = scene.elevator.aim_point(125)-scene.camera.global_position
			scene.player.rotation.y = atan2(-direction.x,-direction.z)
			scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
			if not scene.elevator.interact():
				fail("Cannot select return lift stop")
				return
			for tick in range(1200):
				await physics_frame
				var delta: float = scene.player.get_physics_process_delta_time()
				scene.move_grounded(Vector3.ZERO,delta)
				tick_curse(delta)
				if is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]): break
			if not is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]):
				fail("Return lift did not reach stop")
				return
		if not await move_to(Vector2(-2496,-7614)): return
		if not scene.request_jump():
			fail("Cannot jump back to upper landing")
			return
		if not await move_to(Vector2(-2338,-7614),true): return
		if not scene.wax.ITEM in scene.carried_inventory.collected or not scene.quicksave(chain_save("user://tests/act1_wax_upper_return.json") if earned_checkpoint else "user://tests/hive_wax_upper_fixture.json").is_empty():
			fail("Wax return inventory/checkpoint failed")
			return
		print("PASS: crawlspace exit, reverse lower route, lower platform jump, lift ascent and upper landing with wax")
	var report := {"passed":true,"curse_wax_extension":extended,"wax_return":return_wax,"earned_checkpoint":earned_checkpoint,"scope":"Initial top-platform human spawn supplied; original controls, five-stop descent, lower landing sprint jump, stairs/ramp and 60-unit ledge jump reach wax passage approach without repositioning or flight. Warriors disabled in this local route fixture. No flute-to-platform continuity or curse/pickup claim.","visited":visited}
	if extended:
		report.scope = ("Loaded earned-flute Hive return checkpoint at region393; " if earned_checkpoint else "One supplied human spawn in region393; ")+"source region392 admission, upper approach, platform jump, five-stop descent, lower landing jump, stairs/ramp/ledge, unshortened curse countdown, collision-safe lizard change, crawlspace wax collection and countdown/active-form disk rollback. No later position or form injection. Warriors disabled and manual movement/clock ticks drive this route fixture; native wall-clock parity and earlier quest continuity are not claimed."
	if return_wax:
		report.scope += " Reverse crawlspace, lower route, jump onto platform, ascent and upper landing verified with wax. " + ("Initial state loaded from earned-flute return checkpoint." if earned_checkpoint else "Initial region393 spawn supplied.")
	if cave_chain:
		if not scene.get_node("Warriors").is_processing() or scene.get_node("Warriors").health <= 0 or not "cave:prop641:harvest1:Stalagmite" in scene.carried_inventory.collected:
			fail("Earned wax route lost live guardian combat or original inventory")
			return
		report.scope = "SHA-verified cave-derived flute return through source curse gate, upper approach, exposed platform descent, lower jumps, timed lizard, wax pickup, reverse passage and ascent. Guardian combat stays enabled; nearby enemies are aimed at and struck through production callbacks. Movement/curse ticks remain manually driven. No position/form/inventory/quest injection. Full Executioner and broader content acceptance remain open."
		report.input_sha256 = FileAccess.get_sha256(earned_input)
		report.output_checkpoint_sha256 = FileAccess.get_sha256(chain_save("user://tests/act1_wax_upper_return.json"))
		report.inventory = scene.carried_inventory.collected.duplicate()
		report.health = scene.get_node("Warriors").health
		report.guardian_combat_enabled = scene.get_node("Warriors").is_processing()
	var report_path: String = ("res://docs/hive-wax-return-checks.json" if earned_checkpoint else "res://docs/hive-wax-return-fixture-checks.json") if return_wax else "res://docs/hive-curse-wax-walk-checks.json" if extended else "res://docs/hive-lift-wax-walk-checks.json"
	var file := FileAccess.open(chain_proof(report_path),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	scene.free()
	print("PASS: continuous platform descent, lower landing jump and wax passage approach")
	quit()
