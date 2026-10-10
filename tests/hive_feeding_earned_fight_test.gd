extends "res://tests/hive_lift_wax_walk_test.gd"
## Actual combat continuation from the earned feeding-encounter arrival.
func run() -> void:
	Engine.time_scale=4;Engine.physics_ticks_per_second=240
	cave_chain=true;extended=true;earned_checkpoint=true
	earned_input="user://tests/act1_feeding_earned_arrival.json"
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-feeding-earned-walk-checks.json"))
	if FileAccess.get_sha256(earned_input)!=prior.output_sha256: fail("Earned feeding input hash mismatch");return
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
	var pop=scene.ambush_population
	var guards=scene.get_node("Warriors")
	var spells=scene.starting_magic
	var casts:=0
	var strikes:=0
	for i in range(12000):
		await physics_frame
		if guards.health<=0: fail("Player died in earned feeding fight");return
		if scene.resets!=0 or scene.flying: fail("Earned fight left ordinary collision");return
		if pop.state.actors["35"].health<=0: break
		var target: Vector3=pop.bodies["35"].global_position
		scene.camera.look_at(target)
		if not spells.protected() and spells.cast(5): casts+=1
		var delta: float=scene.player.get_physics_process_delta_time()
		var offset: Vector3=target-scene.camera.global_position
		var distance:=offset.length()
		if distance<94 and guards.strike(): strikes+=1
		var desired:=68.0 if spells.protected() else 85.0
		var direction:=Vector3(offset.x,0,offset.z).normalized()
		if distance<desired-2: direction=-direction
		elif distance<=desired+2: direction=Vector3.ZERO
		scene.move_grounded(direction,delta,true)
		tick_curse(delta)
	if pop.state.actors["35"].health!=0: fail("Earned feeding fight exceeded budget");return
	print("Earned feeding Executioner defeated: casts=",casts," strikes=",strikes," health=",guards.health," position=",scene.player.position)
	# Walk back to the same lower landing, jump onto the continuously positioned lift.
	if not await move_to(Vector2(-2563,-8003)): return
	if not await move_to(Vector2(-2564,-7820)): return
	if not scene.request_jump(): fail("Cannot jump back to earned lift");return
	if not await move_to(Vector2(-2564,-7670),true,300): return
	if not await move_to(Vector2(-2564,-7614)): return
	if not scene.elevator.standing_on_floor(-619): fail("Earned fight did not return to lift");return
	var output:="user://tests/act1_feeding_earned_defeated.json"
	error=scene.quicksave(output)
	if not error.is_empty(): fail(error);return
	var before: Dictionary=pop.checkpoint()
	if not scene.quickload(output).is_empty() or pop.checkpoint()!=before: fail("Earned defeated JSON changed encounter");return
	var report:={"passed":true,"input_save":earned_input,"input_sha256":FileAccess.get_sha256(earned_input),"input_proof":"docs/hive-feeding-earned-walk-checks.json","output_save":output,"output_sha256":FileAccess.get_sha256(output),"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"ambush":pop.checkpoint(),"casts":casts,"strikes":strikes,"health":guards.health,"scope":"Hash-linked earned encounter arrival, actual maximum Spark and aimed melee, ordinary movement, defeated actor35, walked/jumped return to stop2 lift and JSON rollback. No position/inventory/quest/form injections. Accelerated clocks/manual movement and curse ticks are test adapters; earlier route legs reused, not full Act One."}
	FileAccess.open("res://docs/hive-feeding-earned-fight-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS earned feeding fight and return to lift")
	quit()
