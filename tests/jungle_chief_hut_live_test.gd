extends "res://tests/jungle_aloe_use_test.gd"
var puzzle
func aim_rock() -> bool:
	var target: Vector3=puzzle.rock.global_position+Vector3.UP*26
	for i in 12:
		var angle:=TAU*float(i)/12.0
		scene.player.global_position=puzzle.rock.global_position+Vector3(sin(angle)*85,32,cos(angle)*85)
		scene.player.velocity=Vector3.ZERO
		scene.camera.look_at(target)
		await physics_frame
		if puzzle.aimed(): return true
	return false
func step(seconds: float) -> void:
	for i in int(round(seconds*60)):
		puzzle.advance(1.0/60.0)
func run() -> void:
	var path:="user://tests/chief_hut_live.json"
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene);scene.village_alarm.set_physics_process(false);scene.drunk.set_physics_process(false);scene.inner_gate.set_physics_process(false)
	puzzle=scene.chief_hut;puzzle.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(puzzle!=null and puzzle.floors.size()==12,"Puzzle presentation missing"): return
	# Supplied prior conversation; gate opening itself is produced by actual source-region entry.
	scene.kelsrick.run_external(0,["c60000000802"])
	var region: Dictionary=puzzle.src.regions.filter(func(r):return int(r.id)==2147)[0]
	var centre:=Vector2.ZERO
	for p in region.polygon: centre+=Vector2(p[0],p[1])
	centre/=float(region.polygon.size())
	scene.player.global_position=Vector3(centre.x,float(region.floor_min)+scene.FormBody.FOOT_OFFSET,centre.y)
	puzzle.advance(1.0/60)
	if not check(puzzle.state.locals["9"]==1,"Source region did not raise water gate"):return
	# Actual camera visibility admits the pool controller.
	var visible:=false
	for offset in [Vector3(0,32,0),Vector3(0,32,25),Vector3(25,32,0),Vector3(-25,32,0),Vector3(0,32,-25),Vector3(0,32,75),Vector3(75,32,0),Vector3(-75,32,0),Vector3(0,32,-75)]:
		scene.player.global_position=Vector3(-3073,-40,-5033)+offset
		scene.camera.look_at(Vector3(-3073,-23,-5033))
		await physics_frame
		if puzzle.pool_visible(): visible=true;break
	if not visible:
		var target:=Vector3(-3073,-23,-5033)
		var ray:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,target,1,[scene.player.get_rid(),puzzle.rock.get_rid()])
		print("Pool visibility diagnostic ",scene.camera.global_position," frustum=",scene.camera.is_position_in_frustum(target)," hit=",scene.get_world_3d().direct_space_state.intersect_ray(ray))
	if not check(visible,"Pool has no clear local approach"): return
	step(1.2)
	if not check(puzzle.state.locals["11"]==1 and puzzle.state.floor_heights["3742"]==-25,"Pool did not rise"):return
	if not check(await aim_rock(),"Cannot aim at oil rock"):return
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	puzzle._unhandled_input(click)
	if not check(puzzle.state.locals["10"]==1 and puzzle.state.rock==0,"Armed rock strike failed"):return
	step(0.5)
	if not check(puzzle.state.floor_presets["3742"]==30 and puzzle.state.rock==1,"Oil floor material/raised-water rock state absent"):return
	scene.starting_magic.select_spell("spark")
	if not check(scene.starting_magic.cast(),"Production Spark cast rejected"):return
	if not check(puzzle.state.phase=="fire","Actual Spark ray did not ignite rock"):return
	step(5)
	if not check(scene.quicksave(path).is_empty(),"Mid-fire save rejected"):return
	var saved: Dictionary=puzzle.checkpoint()
	step(2)
	var load_error: String=scene.quickload(path)
	if not load_error.is_empty() or puzzle.checkpoint()!=saved: print("Fire rollback diagnostic ",load_error," expected=",saved," actual=",puzzle.checkpoint())
	if not check(load_error.is_empty() and puzzle.checkpoint()==saved,"Mid-fire rollback differs"):return
	var paused_state: Dictionary=puzzle.checkpoint()
	paused=true;puzzle.advance(1);paused=false
	if not check(puzzle.checkpoint()==paused_state,"Pause advanced puzzle"):return
	step(12)
	if not check(puzzle.state.phase=="movie" and puzzle.overlay.visible and scene.actor_input_locked() and scene.kelsrick.local_value(6)==1,"Smoke-out movie/lock/shared flag missing"):return
	if not check(scene.quicksave(path).is_empty(),"Mid-movie save rejected"):return
	var movie_saved: Dictionary=puzzle.checkpoint()
	step(1)
	if not check(scene.quickload(path).is_empty() and puzzle.checkpoint()==movie_saved,"Mid-movie rollback differs"):return
	var soul: int=scene._kelsrick_context().shared["0"]
	step(5)
	if not check(puzzle.state.phase=="done" and not puzzle.overlay.visible and not scene.actor_input_locked(),"Movie did not release player"):return
	if not check(scene._kelsrick_context().shared["0"]==maxi(0,soul-1) and scene.kelsrick.local_value(8)==200,"Smoke-out outcome differs"):return
	if not check(scene.inner_gate.state.leaves["74"].target==100 and scene.inner_gate.state.leaves["75"].target==100,"Smoke-out did not open inner gate"):return
	var done: Dictionary=puzzle.checkpoint()
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Completed puzzle save rejected"):return
	step(5)
	if not check(puzzle.checkpoint()==done and scene._kelsrick_context().shared["0"]==maxi(0,soul-1),"Completion repeated after reload"):return
	await finish(scene)
	DirAccess.remove_absolute(path)
	print("PASS chief hut live region/camera producers, raised surfaces, armed strike, real Spark, saved fire/movie rollback, pause, original movie, shared soul/Kelsrick outcomes and gate opening once. Supplied prior talk/local approaches; earned route pending.")
	quit()
