extends "res://tests/player_magic_handoff_test.gd"
func run() -> void:
	for area in ["hive_review","jungle_walkthrough"]:
		var scene=load("res://scenes/lol2/"+area+".tscn").instantiate()
		root.add_child(scene);current_scene=scene
		await process_frame
		await physics_frame
		scene.set_physics_process(false)
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var expected:=-3512.0 if area=="hive_review" else -2048.0
		if not check(scene.fall_reset_height==expected,"Wrong area recovery boundary"): return
		if area=="hive_review":
			var row: Dictionary=scene.ambush_population.data.regions.filter(func(r): return int(r.region)==444)[0]
			var center:=Vector2.ZERO
			for point in row.polygon: center+=Vector2(point[0],point[1])
			center/=row.polygon.size()
			scene.player.position=Vector3(center.x,-2968,center.y)
			for i in range(12):
				await physics_frame
				scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
			if not check(scene.resets==0 and scene.player.is_on_floor() and absf(scene.player.position.y+2968)<0.2,"Original lower Hive floor reset player"): return
		scene.player.position=Vector3(30000,expected-1,30000)
		scene.player.velocity=Vector3.ZERO
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
		if not check(scene.resets==1 and scene.player.position.is_equal_approx(scene.start),"Void recovery failed"): return
		scene.queue_free()
		await process_frame
	print("PASS Hive lower floor and Hive/Jungle void recovery boundaries")
	quit()
