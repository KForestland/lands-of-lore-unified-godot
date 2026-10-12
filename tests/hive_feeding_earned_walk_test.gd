extends "res://tests/hive_lift_wax_walk_test.gd"
## Continuation from a hash-verified earned flute return; no later pose/quest grants.
func run() -> void:
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	cave_chain=true;extended=true;earned_checkpoint=true
	earned_input="user://tests/act1_population_broken_flute_hive_return.json"
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/population-earned-flute-return-walk-checks.json"))
	if FileAccess.get_sha256(earned_input)!=prior.output_sha256:
		fail("Earned flute input hash mismatch");return
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	var error: String=scene.quickload(earned_input)
	if not error.is_empty(): fail(error);return
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	scene.hive_curse.set_physics_process(false)
	root.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in range(10):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
		tick_curse(scene.player.get_physics_process_delta_time())
	if not await move_to(Vector2(-1041.5,-8184.75)): return
	var upper: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_curse_lift_route.json"))
	for point in upper.points:
		if not await move_to(Vector2(point[0],point[1])): return
	if not await move_to(Vector2(-2355,-7614)): return
	if not scene.request_jump(): fail("Cannot jump onto earned lift");return
	if not await move_to(Vector2(-2510,-7614),true): return
	if not await move_to(Vector2(-2564.5,-7614.5)): return
	print("Earned top platform reached ",scene.player.position)
	for stop in [1,2]:
		var direction: Vector3=scene.elevator.aim_point(125)-scene.camera.global_position
		scene.player.rotation.y=atan2(-direction.x,-direction.z)
		scene.camera.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
		if not scene.elevator.interact(): fail("Cannot select earned lift stop");return
		for i in range(150):
			await physics_frame
			scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
			tick_curse(scene.player.get_physics_process_delta_time())
		if not is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]): fail("Lift did not reach requested stop");return
	print("Earned stop2 reached ",scene.player.position)
	if not await move_to(Vector2(-2564,-7680)): return
	if not scene.request_jump(): fail("Cannot jump to feeding landing");return
	if not await move_to(Vector2(-2564,-7840),true,300): return
	if not await move_to(Vector2(-2563,-8003)): return
	var pop=scene.ambush_population
	for i in range(480):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
		tick_curse(scene.player.get_physics_process_delta_time())
		if pop.state.actors["35"].active: break
	if not pop.state.contact716 or not pop.state.actors["35"].active: fail("Earned region did not activate feeding encounter");return
	if scene.get_node("Warriors").health<=0 or scene.resets!=0 or scene.flying: fail("Earned arrival lost normal play state");return
	var output:="user://tests/act1_feeding_earned_arrival.json"
	error=scene.quicksave(output)
	if not error.is_empty(): fail(error);return
	var report:={"passed":true,"input_save":earned_input,"input_sha256":FileAccess.get_sha256(earned_input),"input_proof":"docs/population-earned-flute-return-walk-checks.json","output_save":output,"output_sha256":FileAccess.get_sha256(output),"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"ambush":pop.checkpoint(),"lift":scene.elevator.checkpoint,"health":scene.get_node("Warriors").health,"scope":"Earned flute return, source upper route, actual lift control to stop2, jumped lower landing and walked region716. No added position/inventory/quest/form injection. Manually driven movement/curse and accelerated clocks. Proves approach/activation, not encounter defeat or full Act One."}
	FileAccess.open("res://docs/hive-feeding-earned-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS earned feeding encounter approach and activation ",scene.player.position)
	quit()
