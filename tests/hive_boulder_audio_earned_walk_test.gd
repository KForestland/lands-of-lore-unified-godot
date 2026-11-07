extends "res://tests/hive_lift_wax_walk_test.gd"
var route_failed:=false
var morphs: Array=[]
func tick_curse(delta: float) -> void:
	var previous: int=scene.player_form
	super.tick_curse(delta)
	if scene.player_form!=previous: morphs.append({"from":previous,"to":scene.player_form,"health":scene.get_node("Warriors").health})
func fail(message: String) -> bool:
	route_failed=true
	return super.fail(message)
func run() -> void:
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	cave_chain=true
	extended=true
	earned_checkpoint=true
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-unfold-earned-fight-checks.json"))
	earned_input=prior.output_save
	if FileAccess.get_sha256(earned_input)!=prior.output_sha256: fail("Earned boulder input hash mismatch");return
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	var error: String=scene.quickload(earned_input)
	if not error.is_empty(): fail(error);return
	if scene.boulder_surfaces.state.phase!=0: fail("Earned trap already started");return
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	scene.hive_curse.set_physics_process(false)
	root.grab_focus()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for stop in [5,6]:
		var direction: Vector3=scene.elevator.aim_point(125)-scene.camera.global_position
		scene.player.rotation.y=atan2(-direction.x,-direction.z)
		scene.camera.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
		if not scene.elevator.interact(): fail("Cannot select boulder lift stop");return
		for i in range(150):
			await physics_frame
			var delta: float=scene.player.get_physics_process_delta_time()
			scene.move_grounded(Vector3.ZERO,delta)
			tick_curse(delta)
		if not is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]): fail("Wrong boulder lift stop");return
	if not await move_to(Vector2(-2565,-7547)): return
	if not scene.request_jump(): fail("Cannot jump to stop6 landing");return
	if not await move_to(Vector2(-2565,-7385),true,300): return
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_boulder_stop6_route.json"))
	for point in route.points:
		if not await move_to(Vector2(point[0],point[1]),true): return
	for i in range(1100):
		await physics_frame
		var delta: float=scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3.ZERO,delta)
		tick_curse(delta)
		if scene.boulder_surfaces.state.phase==3 and scene.boulder_surfaces.state.elapsed==scene.boulder_surfaces.State.OPEN_SECONDS: break
	if scene.boulder_surfaces.state.phase!=3 or scene.boulder_surfaces.state.elapsed!=scene.boulder_surfaces.State.OPEN_SECONDS: fail("Earned surface chain did not finish");return
	if not await move_to(Vector2(-2058,-6700),true): return
	if route_failed or scene.get_node("Warriors").health<=0 or scene.resets!=0 or scene.flying: fail("Invalid earned boulder completion state");return
	for actor in scene.boulders.state.actors.values():
		if not actor.active or not actor.stopping or actor.rolling or actor.index<=0: fail("Earned boulder actor did not move and stop");return
	if scene.boulders.state.legacy_retired: fail("Earned boulders were retired as legacy");return
	var output:="user://tests/act1_boulder_audio_earned_exit.json"
	error=scene.quicksave(output)
	if not error.is_empty(): fail(error);return
	var report:={"passed":true,"input_save":earned_input,"input_sha256":FileAccess.get_sha256(earned_input),"output_save":output,"output_sha256":FileAccess.get_sha256(output),"surfaces":scene.boulder_surfaces.checkpoint(),"actors":scene.boulders.checkpoint(),"audio":scene.boulder_audio.checkpoint(),"health":scene.get_node("Warriors").health,"natural_morphs":morphs,"player_position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"scope":"SHA-verified earned lower-fight save, production lift stops5/6, ordinary jump/walk through13 source regions, live surface trigger/descent/exit. No pose/form/item/quest injection after load. Accelerated manually driven movement/curse ticks. Original boulder visuals and saved path/fall/stop motion are active. Original close, rolling and exit cues are live with saved clocks; Godot spatial mixing remains an adapter. Player contact response/damage remains disabled, so this is not complete hazard acceptance. Earlier campaign legs reused."}
	FileAccess.open("res://docs/hive-boulder-audio-earned-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ",true,true)+"\n")
	print("PASS earned original boulder activation, saved path motion/stop, surface descent and exit; contact damage pending")
	quit()
