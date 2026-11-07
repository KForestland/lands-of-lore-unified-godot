extends "res://tests/hive_earned_rune_walk_test.gd"
var hold_waits:=0
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
				# route does not offer her anything: it waits until her own timers end the wait and she leaves.
				for hold_tick in range(240*240):
					await physics_frame
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
	var input_path := chain_save("user://tests/act1_earned_runes.json")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chain_proof("res://docs/hive-earned-rune-walk-checks.json")))
	if FileAccess.get_sha256(input_path) != proof.get("output_sha256","") or not scene.quickload(input_path).is_empty():
		fail("Earned rune save/proof mismatch")
		return
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(cave_chain)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_rune_return_routes.json"))
	if not await walk_return(routes.upper_to_exit,true): return
	for tick in range(180):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/jungle_walkthrough.tscn": break
	if not is_instance_valid(current_scene) or current_scene.scene_file_path != "res://scenes/lol2/jungle_walkthrough.tscn":
		fail("Rune return did not transition to Jungle")
		return
	scene = current_scene
	scene.set_physics_process(false)
	if not await walk_return(routes.jungle_to_monastery,false,"MENT"): return
	if not scene.monastery.active() or scene.monastery.state().room != "MENT" or scene.carried_collected != original_inventory or scene.monastery.state().globals.GV_HAS_RUNES != 1:
		fail("Earned rune monastery arrival state differs")
		return
	var output_path := chain_save("user://tests/act1_runes_monastery_return.json")
	if not scene.quicksave(output_path).is_empty():
		fail("Monastery rune return save failed")
		return
	var dawn_seen: Dictionary={}
	if scene.get("dawn")!=null and is_instance_valid(scene.dawn): dawn_seen={"present":scene.dawn.state.present,"owner_state":scene.dawn.state.owner_state,"talked":int(scene.dawn.state.locals["19"]),"groups":scene.dawn.effect_log.filter(func(e):return e.type=="group").map(func(e):return e.group)}
	var report := {"passed":true,"actor_hold_waits":hold_waits,"world_dawn":dawn_seen,"input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"inventory":scene.carried_collected,"scope":"Earned rune save continuation, reverse48 corridor portals, lowest platform jump, ascent, upper landing jump,101 Hive and117 Jungle source-region routes through actual area transition into MENT. No test position/form/quest injection. Hive warriors disabled; movement and curse clocks driven manually. Monastery return conversation not yet implemented."}
	if cave_chain:
		report.scope = report.scope.replace("warriors disabled","guardian combat enabled").replace("Hive warriors disabled","Hive guardian combat enabled").replace("Monastery return conversation not yet implemented.","Returns to MENT; Julian translation checked by the next leg.")
		report.cave_derived = true
		if not "cave:prop641:harvest1:Stalagmite" in report.inventory:
			fail("Cave weapon lost during rune route")
			return
	var file := FileAccess.open(chain_proof("res://docs/hive-earned-rune-return-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: earned runes returned through Hive/platform/Jungle to monastery without repositioning")
	quit()
