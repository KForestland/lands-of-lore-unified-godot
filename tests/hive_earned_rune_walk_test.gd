extends "res://tests/hive_lift_wax_walk_test.gd"
const RuneItems = preload("res://scripts/lol2/hive_rune_items.gd")
func _initialize() -> void:
	extended = true
	run.call_deferred()
func aim(point: Vector3) -> void:
	var direction: Vector3 = point-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func total_experience(player: Dictionary) -> int:
	var total := int(player.experience)
	var thresholds = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_reward_thresholds.json")).thresholds
	for level in range(1,int(player.level)): total += int(thresholds[level])
	return total

# A fresh earned save can arrive cursed after longer combat. Return along the
# already-used ground corridor to the original repeatable human-return gate.
# Never force a form or wait exposed beside the upper-platform jump.
func return_to_human_gate() -> bool:
	if scene.player_form==0: return true
	print("Returning through source region393 before lift jump; form=",scene.player_form)
	var upper: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_curse_lift_route.json"))
	for index in range(upper.points.size()-1,-1,-1):
		var point: Array=upper.points[index]
		if not await move_to(Vector2(point[0],point[1])): return false
	if not await move_to(Vector2(-1041.5,-8184.75)): return false
	if not await move_to(Vector2(-1066.5,-8310.25)): return false
	for frame in range(600):
		await physics_frame
		var delta: float=scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3.ZERO,delta)
		tick_curse(delta)
		if scene.resets!=0 or scene.get_node("Warriors").health<=0:
			return fail("Human-return detour reset or killed player")
		if scene.player_form==0 and scene.curse.state.phase==0: break
	if scene.player_form!=0 or scene.curse.state.phase!=0:
		return fail("Source human-return gate did not settle")
	print("Source human-return gate restored human form; no form injection")
	if not await move_to(Vector2(-1041.5,-8184.75)): return false
	for point in upper.points:
		if not await move_to(Vector2(point[0],point[1])): return false
	return true

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	if cave_chain: current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	for frame in range(3): await process_frame
	scene.set_development_mode(false)
	var input_path := chain_save("user://tests/act1_wax_upper_return.json")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chain_proof("res://docs/hive-wax-return-checks.json")))
	if not proof.get("earned_checkpoint",false) or FileAccess.get_sha256(input_path) != proof.get("output_checkpoint_sha256",""):
		fail("Wax checkpoint does not match the earned-route proof")
		return
	if not scene.quickload(input_path).is_empty():
		fail("Earned wax checkpoint unavailable")
		return
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(cave_chain)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The earned wax save may end mid-curse. Keep the source curse clocks live
	# (extended mode) so source gates such as region393 return the player to human.
	if scene.player_form != 0:
		extended = true
		print("Earned wax save is cursed (form ",scene.player_form,"); curse clocks stay live")
	if not "hive:item0:Wax" in scene.carried_inventory.collected:
		fail("Earned checkpoint lacks wax")
		return
	for tick in range(10):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	if not await return_to_human_gate(): return
	if scene.player_form!=0:
		fail("Curse changed again before upper-platform jump")
		return
	if not await move_to(Vector2(-2355,-7614)): return
	if not scene.request_jump():
		fail("Cannot jump onto upper platform")
		return
	if not await move_to(Vector2(-2510,-7614),true): return
	if not await move_to(Vector2(-2564.5,-7614.5)): return
	for stop in range(1,8):
		aim(scene.elevator.aim_point(125))
		if not scene.elevator.interact():
			var point: Vector3 = scene.elevator.aim_point(125)
			var offset: Vector3 = point-scene.camera.global_position
			var query := PhysicsRayQueryParameters3D.create(scene.camera.global_position,point,1,[scene.player.get_rid()])
			query.hit_from_inside = true
			print("Lift selection failure: stop=",stop," position=",scene.player.position," camera=",scene.camera.global_position," form=",scene.player_form," mouse=",Input.mouse_mode," cursor=",scene.interface_hud.cursor_active," health=",scene.get_node("Warriors").health," distance=",offset.length()," aim_dot=",(-scene.camera.global_basis.z).dot(offset.normalized())," ray=",scene.get_world_3d().direct_space_state.intersect_ray(query))
			fail("Cannot select rune descent stop")
			return
		for tick in range(1200):
			await physics_frame
			var delta: float = scene.player.get_physics_process_delta_time()
			scene.move_grounded(Vector3.ZERO,delta)
			tick_curse(delta)
			if is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]): break
		if not is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]):
			fail("Rune descent did not reach stop")
			return
	if not await move_to(Vector2(-2500,-7560)): return
	if not scene.request_jump():
		fail("Cannot jump to lowest landing")
		return
	if not await move_to(Vector2(-2395,-7460),true): return
	print("Lowest landing reached: ",scene.player.position)
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_lift_rune_route.json"))
	for index in range(route.points.size()):
		var point: Array = route.points[index]
		if not await move_to(Vector2(point[0],point[1])): return
		visited.append({"portal":index,"region":route.regions[index],"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z]})
		print("Reached rune portal ",index," region ",route.regions[index]," at ",scene.player.position)
	aim(scene.rune_light.aim_point())
	await physics_frame
	var mana_before_light := int(scene.player_magic_checkpoint.player.mana)
	key(KEY_G)
	if int(scene.player_magic_checkpoint.player.mana) != mana_before_light-1:
		fail("Rune light did not debit one mana")
		return
	if not scene.runes.checkpoint.lights:
		fail("Earned arrival could not light source prop: "+str(scene.player.position))
		return
	# Upper face center of the original control mesh, visible from the approach.
	aim(Vector3(-3157.044,-1657,-6177.584))
	await physics_frame
	key(KEY_E)
	if not scene.runes.active():
		fail("Earned arrival could not enter rune room")
		return
	var entry = scene.runes
	if not entry.activate_hotspot(2):
		fail("Lit inscription rejected")
		return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	var wax_index := -1
	for index in range(entry.held.item_count):
		if entry.held.get_item_metadata(index) == "hive:item0:Wax": wax_index = index
	if wax_index < 1:
		fail("Earned wax missing from held selector")
		return
	entry.held.select(wax_index)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var fight_before := total_experience(scene.player_reward_checkpoint.player)
	var magic_before := total_experience(scene.player_magic_checkpoint.player)
	var mana_before_copy := int(scene.player_magic_checkpoint.player.mana)
	var maximum_before_copy := int(scene.player_magic_checkpoint.player.maximum)
	entry.hotspots[4].gui_input.emit(event)
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	var copies := 0
	for item in scene.carried_inventory.collected:
		if RuneItems.valid(item): copies += 1
	if copies != 1 or "hive:item0:Wax" in scene.carried_inventory.collected or scene.monastery_checkpoint.globals.GV_HAS_RUNES != 1:
		fail("Earned wax transaction failed")
		return
	if total_experience(scene.player_reward_checkpoint.player) != fight_before+200 or total_experience(scene.player_magic_checkpoint.player) != magic_before+200 or int(scene.player_magic_checkpoint.player.mana)-mana_before_copy != int(scene.player_magic_checkpoint.player.maximum)-maximum_before_copy:
		# The copy spends no mana; a level-up from its +200 magic XP (D8B94) raises maximum and mana by the same gain.
		print("RUNE COPY DIAG fight ",fight_before,"->",total_experience(scene.player_reward_checkpoint.player)," magic ",magic_before,"->",total_experience(scene.player_magic_checkpoint.player)," mana ",mana_before_copy,"->",scene.player_magic_checkpoint.player.mana," magic_player=",scene.player_magic_checkpoint.player," regen=",scene.player_magic_checkpoint.get("regen_elapsed"))
		fail("Earned rune copy reward/mana mismatch")
		return
	if not "monastery:item94:Iron_Flute" in scene.carried_inventory.collected:
		fail("Rune copy lost earned flute")
		return
	entry.leave()
	if stone_route:
		if not entry.activate_hotspot(4):
			fail("Earned lit rune room did not admit Ancient Stone pickup")
			return
		for frame in range(600):
			await process_frame
			if entry.checkpoint.flag7 and not entry.busy(): break
		if not entry.checkpoint.flag7 or preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM not in scene.carried_inventory.collected:
			fail("Original stone movie did not grant earned Ancient Stone")
			return
		print("PASS earned Ancient Stone through original hotspot/movie; no item or flag injection")
	entry.leave()
	scene.set_physics_process(false)
	for tick in range(30):
		await physics_frame
		var delta: float = scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3.ZERO,delta)
		tick_curse(delta)
	print("Rune return settled: ",scene.player.position," on_floor=",scene.player.is_on_floor())
	if not scene.player.is_on_floor() or scene.resets != 0:
		fail("Rune room return did not settle on original floor")
		return
	var output_path := chain_save("user://tests/act1_earned_runes.json")
	if not scene.quicksave(output_path).is_empty():
		fail("Earned rune checkpoint save failed")
		return
	var report := {"passed":true,"scope":"Earned wax save continuation through seven-stop lift descent, lowest landing jump, source corridor, aimed Spark, room entry and GUI wax copying. No position/form/quest injection; warriors disabled and movement/curse clock driven manually for this local leg.","input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"visited":visited,"inventory":scene.carried_inventory.collected}
	report.return_floor = {"region":scene.runes.data.return_pose.support_region,"height":scene.runes.data.return_pose.support_floor,"settled_position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"grounded":scene.player.is_on_floor(),"adapter":"Preserve source XZ/bearing and higher incoming height; lift an embedded body to source support plus foot offset and safe margin."}
	if cave_chain:
		report.scope = report.scope.replace("warriors disabled","guardian combat enabled").replace("Hive warriors disabled","Hive guardian combat enabled").replace("Monastery return conversation not yet implemented.","Returns to MENT; Julian translation checked by the next leg.")
		report.cave_derived = true
		if not "cave:prop641:harvest1:Stalagmite" in report.inventory:
			fail("Cave weapon lost during rune route")
			return
	var file := FileAccess.open(chain_proof("res://docs/hive-earned-rune-walk-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: earned wax to copied runes through lift, walk, Spark and room without repositioning")
	quit()
