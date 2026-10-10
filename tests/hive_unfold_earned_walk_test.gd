extends "res://tests/hive_lift_wax_walk_test.gd"
var route_failed := false
func fail(message: String) -> bool:
	route_failed=true
	return super.fail(message)
func run() -> void:
	Engine.time_scale=4;Engine.physics_ticks_per_second=240
	cave_chain=true;extended=true;earned_checkpoint=true
	earned_input="user://tests/act1_feeding_earned_defeated.json"
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-feeding-earned-fight-checks.json"))
	if FileAccess.get_sha256(earned_input)!=prior.output_sha256: fail("Earned unfold input hash mismatch");return
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	var error: String=scene.quickload(earned_input)
	if not error.is_empty(): fail(error);return
	if scene.ambush_population.state.actors["33"].active or scene.ambush_population.state.actors["33"].health!=400: fail("Earned source must precede actor33 activation");return
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	scene.hive_curse.set_physics_process(false)
	root.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for stop in [3,4]:
		var direction: Vector3=scene.elevator.aim_point(125)-scene.camera.global_position
		scene.player.rotation.y=atan2(-direction.x,-direction.z)
		scene.camera.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
		if not scene.elevator.interact(): fail("Cannot select lift stop");return
		for i in range(150):
			await physics_frame
			var delta: float=scene.player.get_physics_process_delta_time()
			scene.move_grounded(Vector3.ZERO,delta)
			tick_curse(delta)
		if not is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]): fail("Wrong lift stop");return
	if not await move_to(Vector2(-2630,-7610)): return
	if not scene.request_jump(): fail("Cannot jump to stop4 west landing");return
	if not await move_to(Vector2(-2775,-7610),true,300): return
	print("Earned stop4 west landing ",scene.player.position)
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_unfold_stop4_route.json"))
	for i in range(route.points.size()):
		print("Unfold route point ",i," region ",route.regions[mini(i+1,route.regions.size()-1)])
		var point: Array=route.points[i]
		if not await move_to(Vector2(point[0],point[1]),true): return
	for i in range(600):
		await physics_frame
		var delta: float=scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3.ZERO,delta)
		tick_curse(delta)
		if scene.ambush_population.state.actors["33"].active: break
	if not scene.ambush_population.state.actors["33"].active: fail("Unfold encounter not active");return
	if route_failed or scene.get_node("Warriors").health<=0 or scene.resets!=0 or scene.flying: fail("Invalid earned completion state");return
	var output:="user://tests/act1_unfold_earned_arrival.json"
	error=scene.quicksave(output)
	if not error.is_empty(): fail(error);return
	var report:={"passed":true,"input_save":earned_input,"input_sha256":FileAccess.get_sha256(earned_input),"output_save":output,"output_sha256":FileAccess.get_sha256(output),"ambush":scene.ambush_population.checkpoint(),"scope":"Earned save, production lift stop4 west landing, manual ordinary movement, no subsequent pose/form/item/quest injection. Accelerated clocks; earlier legs reused."}
	FileAccess.open("res://docs/hive-unfold-earned-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS earned unfolding encounter arrival")
	quit()
