extends "res://tests/hive_earned_rune_walk_test.gd"
# Separate earned branch from r12w campaign q_fresh_chain/06_runes.log.
# Input hash pins that artifact; it does not claim a fresh upstream qualification.
const INPUT = "~/AI_COMMS/act1_completion_20261017/r12w_qualification/campaign/userdata/act1_broken_earned_runes.json"
const INPUT_SHA = "12acf30f87aa24874bea60bed79ceacee3564aa3a9dcf665cbc9481f314541d0"
var hold_waits:=0
func _initialize() -> void:
	extended=true
	cave_chain=true
	broken_route=true
	run.call_deferred()
func _actor_hold() -> bool:
	if scene==null or not is_instance_valid(scene) or not scene.has_method("actor_input_locked"): return false
	return scene.actor_input_locked() or (scene.get("dawn")!=null and is_instance_valid(scene.dawn) and scene.dawn.movement_locked())
func walk_return(route: Dictionary, allow_exit := false, destination_room := "") -> bool:
	for index in range(route.points.size()):
		var target := Vector2(route.points[index][0],route.points[index][1])
		var reached := false
		for step in range(1200):
			await physics_frame
			if allow_exit and current_scene != scene: return true
			if allow_exit and scene.get("departure") != null and scene.departure.active():
				# A blocking cinematic must not consume the short movement-stall budget.
				for movie_tick in range(3600):
					await process_frame
					if current_scene != scene: return true
					if not scene.departure.active(): break
				if scene.departure.active(): return fail("Departure movie did not finish")
				continue
			if _actor_hold():
				# World Dawn63 (HAS_RUNES on regions2812/2842) holds the player through her talk and wait. This earned
				# route offers the actually carried runes while her original wait is active.
				for hold_tick in range(240*240):
					await physics_frame
					if scene.get("dawn")!=null and scene.dawn.state.present and scene.dawn.movement_locked() and not scene.dawn.talking():
						var runes: Array=scene.carried_collected.filter(func(id):return RuneItems.valid(id))
						if not runes.is_empty():
							var dawn=scene.dawn
							aim(dawn.population.bodies[dawn.ID].global_position+Vector3.UP*36)
							if scene.hand_item!=runes[0]:assert(scene.hold_in_hand(runes[0]))
							if dawn.use():print("EARNED offered actual wax runes to live Dawn63")
					if not _actor_hold(): break
				if _actor_hold():
					var d=scene.get("dawn")
					if d!=null and is_instance_valid(d): print("DAWN HOLD DIAG world_active=",d.world_active()," paused=",paused," physics=",d.is_physics_processing()," state=",JSON.stringify(d.state).left(600)," hold=",d.hold," talking=",d.talking()," log=",JSON.stringify(d.effect_log.slice(-8)).left(800))
					return fail("Actor hold did not end")
				hold_waits+=1
				continue
			if not destination_room.is_empty() and scene.monastery.active():
				if scene.monastery.state().room == destination_room: return true
				return fail("Unexpected room during rune return")
			var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
			if offset.length()<2 and scene.player.is_on_floor():
				reached = true
				break
			var delta: float = scene.player.get_physics_process_delta_time()
			var direction := offset.normalized()*minf(1,offset.length()/(80*delta))
			# Face the walking direction, as a player does (only the view turns; movement is unchanged).
			if offset.length()>1: scene.player.rotation.y=atan2(-offset.x,-offset.y)
			scene.move_grounded(Vector3(direction.x,0,direction.y),delta)
			if scene.has_node("Warriors"): tick_curse(delta)
			else: scene.curse.advance(delta)
			if scene.resets != 0 or scene.flying: return fail("Rune return reset or entered flight")
		if reached and index%20==0: print("Return waypoint ",index," region ",route.regions[index]," at ",scene.player.position)
		if not reached: return fail("Rune return blocked at %s region%s position%s" % [index,route.regions[index],scene.player.position])
	print("Rune return segment reached: ",scene.player.position)
	return true
func run() -> void:
	root.size=Vector2i(1280,720)
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	for frame in range(3): await process_frame
	scene.set_development_mode(false)
	var input_path := INPUT
	if FileAccess.get_sha256(input_path) != INPUT_SHA or not scene.quickload(input_path).is_empty():
		fail("Earned rune save/proof mismatch")
		return
	scene.starting_magic.interface_request=true
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(cave_chain)
	print("EARNED INPUT hp/form/mana ",scene.get_node("Warriors").health,"/",scene.player_form,"/",scene.starting_magic.magic_state())
	for i in 3000:
		await physics_frame
		if scene.starting_magic.health()>=25:break
		scene.curse.advance(scene.player.get_physics_process_delta_time())
		scene.starting_magic.select_spell("heal");scene.starting_magic.cast()
	var original_inventory: Array = scene.carried_inventory.collected.duplicate()
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_lift_rune_route.json"))
	# The room returns to679, already above the50-unit drop into506.
	for index in range(47,-1,-1):
		if not await move_to(Vector2(route.points[index][0],route.points[index][1])): return
		print("Reverse rune portal ",index," at ",scene.player.position)
	if not await move_to(Vector2(-2395,-7460)): return
	if not scene.request_jump():
		fail("Cannot jump to lowest platform")
		return
	if not await move_to(Vector2(-2500,-7560),true): return
	if not await move_to(Vector2(-2564.5,-7614.5)): return
	aim(scene.elevator.aim_point(125))
	if not scene.elevator.interact():
		fail("Cannot select return to upper stop")
		return
	for tick in range(1600):
		await physics_frame
		var delta: float = scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3.ZERO,delta)
		tick_curse(delta)
		if is_equal_approx(scene.elevator.checkpoint.height,-235): break
	if not is_equal_approx(scene.elevator.checkpoint.height,-235):
		fail("Rune return platform failed to ascend")
		return
	if not await move_to(Vector2(-2496,-7614)): return
	if not scene.request_jump():
		fail("Cannot jump to upper landing")
		return
	if not await move_to(Vector2(-2338,-7614),true,3600): return
	assert(scene.quicksave("res://tmp/dampen_hive_upper_earned_save.json").is_empty())
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_rune_return_routes.json"))
	if not await walk_return(routes.upper_to_exit,true): return
	for tick in range(180):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/jungle_walkthrough.tscn": break
	if not is_instance_valid(current_scene) or current_scene.scene_file_path != "res://scenes/lol2/jungle_walkthrough.tscn":
		fail("Rune return did not transition to Jungle")
		return
	scene = current_scene
	scene.starting_magic.interface_request=true
	scene.set_physics_process(false)
	if not await walk_return(routes.jungle_to_monastery,false,"MENT"): return
	if not scene.monastery.active() or scene.monastery.state().room!="MENT" or scene.carried_collected!=original_inventory.filter(func(id):return not RuneItems.valid(id)):
		fail("Dawn branch arrival/inventory differs: "+str(scene.carried_collected));return
	if int(scene.dawn.state.locals.get("17",0))!=1:fail("Original Dawn rune offer did not write local17");return
	if not scene.monastery.enter_room("MLIB"):fail("Actual monastery library entry refused");return
	const Speech=preload("res://scripts/lol2/monastery_conversation.gd")
	for i in 20000:
		await process_frame
		if not Speech.active(scene.monastery.state().conversation):break
	scene.monastery.leave_room()
	for i in 20000:
		await process_frame
		if scene.monastery.state().room=="MENT" and not Speech.active(scene.monastery.state().conversation):break
	if scene.carried_collected.count(Speech.DAMPEN)!=1:fail("Actual Dawn translation did not grant charm");return
	var path:="res://tmp/dampen_prerequisite_earned_save.json"
	if not scene.quicksave(path).is_empty() or not scene.quickload(path).is_empty():fail("Earned Dampen save/reload failed");return
	print("PASS separate actual Hive earned runes -> original Dawn offer -> original library translation -> Dampen charm -> real save/reload; no seeds or inventory merge")
	if scene.carried_collected.count(Speech.DAMPEN)!=1 or scene.resets!=0:fail("Reload lost earned charm or route reset");return
	FileAccess.open("res://tmp/dampen_prerequisite_earned_receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"input_sha256":INPUT_SHA,"output_sha256":FileAccess.get_sha256(path),"scope":"Separate earned Dawn offer and library translation, save/reload; no inventory merge."},"  ")+"\n")
	scene.queue_free()
	await process_frame
	quit()

func move_to(target: Vector2, sprint := false, limit := 900) -> bool:
	for step in range(limit):
		await physics_frame
		if scene.interface_hud.cursor_active or scene.runes.active() or paused:return fail("Headless route attempted movement through modal interface")
		if scene.resets != 0 or scene.flying or (not extended and scene.player_form != 0):
			return fail("Route reset, entered flight or changed supplied human form (resets=%d flying=%s form=%d extended=%s health=%d)" % [scene.resets,scene.flying,scene.player_form,extended,scene.get_node("Warriors").health])
		var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
		if offset.length()<2.0 and scene.player.is_on_floor(): return true
		var delta: float = scene.player.get_physics_process_delta_time()
		var speed: float = scene.walk_feel.RUN_SPEED if sprint else scene.walk_feel.WALK_SPEED
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
