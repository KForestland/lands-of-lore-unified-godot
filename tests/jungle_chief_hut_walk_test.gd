extends "res://tests/hive_quest_walk_test.gd"
## Continuous branch after the existing Hive-spawn fixture and earned Kelsrick talk/gate.
var route_jumps := 0
var healing_casts := 0
var dino_strikes := 0
var aura_casts := 0
func evidence_directory() -> String:
	return "res://tmp/chief_hut_walk/"+("resumed" if "--resume-chief-gate" in OS.get_cmdline_user_args() else "continuous")
func puzzle_capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(evidence_directory())
	root.get_texture().get_image().save_png(evidence_directory()+"/"+label+".png")
func defend() -> void:
	if scene==null or scene.get("dino_population")==null: return
	var magic=scene.starting_magic
	var danger:=false
	for target in scene.dino_population.targets().values():
		if scene.camera.global_position.distance_to(target.point)<150: danger=true;break
	if danger and not magic.protected() and int(magic.magic_state().player.mana)>=10:
		magic.select_spell("spark")
		if magic.cast(5): aura_casts+=1
	if magic.health()>0 and magic.health()<=18:
		var previous: String=magic.magic_state().get("spell","spark")
		magic.select_spell("heal")
		if magic.cast(): healing_casts+=1
		magic.select_spell(previous)
	var nearest: Dictionary={}
	var distance:=105.0
	for target in scene.dino_population.targets().values():
		var gap: float=scene.camera.global_position.distance_to(target.point)
		if gap<distance: distance=gap;nearest=target
	if not nearest.is_empty():
		var rotation: Vector3=scene.camera.rotation
		scene.camera.look_at(nearest.point)
		if scene.dino_population.strike(): dino_strikes+=1
		scene.camera.rotation=rotation

func before_walk_step(name: String, _waypoint: int, step: int) -> void:
	defend()
	if scene.get("starting_magic")!=null and not check(scene.starting_magic.health()>0,"Player died during "+name): return
	# Use the normal Space-jump producer for steep ridges; never set velocity or pose.
	if name in ["inner_gate_to_pool","pool_to_village"] and step>0 and step%120==0:
		if scene.request_jump(): route_jumps+=1

func _initialize() -> void:
	inner_gate_route=true
	super._initialize()
func run() -> void:
	if "--resume-chief-gate" not in OS.get_cmdline_user_args():
		await super.run();return
	Engine.time_scale=4.0;Engine.physics_ticks_per_second=240
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	if not check(scene.quickload("user://tests/chief_hut_earned_gate.json").is_empty(),"Prior earned gate checkpoint unavailable"):return
	scene.set_physics_process(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	routes={}
	await finish_inner_gate_route()
func finish_inner_gate_route() -> void:
	var puzzle=scene.chief_hut
	if not check(puzzle!=null,"Chief-hut owner absent"):return
	if "--resume-chief-gate" not in OS.get_cmdline_user_args():
		if not check(scene.quicksave("user://tests/chief_hut_earned_gate.json").is_empty(),"Earned gate checkpoint save failed"):return
	routes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/chief_hut_walk_routes.json")),true)
	if not await walk("inner_gate_to_pool"):return
	if not check(int(puzzle.state.locals["9"])==1,"Earned return did not raise watergate"):return
	scene.camera.look_at(Vector3(-3073,-23,-5033))
	for i in 600:
		await physics_frame
		defend()
		if int(puzzle.state.locals["11"])==1 and float(puzzle.state.floor_heights.get("3742",-40))==-25:break
	if not check(int(puzzle.state.locals["11"])==1,"Earned pool view did not raise water"):return
	await puzzle_capture("raised_pool")
	scene.camera.look_at(puzzle.rock.global_position+Vector3.UP*26)
	await physics_frame
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	puzzle._unhandled_input(click)
	if not check(int(puzzle.state.locals["10"])==1,"Earned rock strike failed at %s"%scene.player.position):return
	for i in 180:
		await physics_frame
		defend()
	for i in 120:
		if float(scene.starting_magic.magic_state().get("cooldown",0))<=0: break
		await physics_frame
	scene.starting_magic.select_spell("spark")
	var cast_ok: bool=scene.starting_magic.cast()
	if not cast_ok or puzzle.state.phase!="fire":
		var ray:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.camera.global_position-scene.camera.global_basis.z*384,3,[scene.player.get_rid()])
		print("Spark diagnostic cast=",cast_ok," state=",puzzle.checkpoint()," hit=",scene.get_world_3d().direct_space_state.intersect_ray(ray)," form=",scene.player_form," available=",scene.starting_magic.available()," health=",scene.starting_magic.health()," magic=",scene.starting_magic.magic_state()," escort=",scene.bacatta.input_locked())
	if not check(cast_ok and puzzle.state.phase=="fire","Earned Spark failed"):return
	await puzzle_capture("ignited_oil")
	if not check(scene.quicksave("user://tests/chief_hut_earned_fire.json").is_empty(),"Earned fire save failed"):return
	var movie_captured:=false
	for i in 6000:
		await physics_frame
		defend()
		if puzzle.state.phase=="movie" and not movie_captured:
			await puzzle_capture("hut_movie")
			movie_captured=true
		if puzzle.state.phase=="done":break
	if not check(puzzle.state.phase=="done" and scene.resets==0,"Earned smoke-out failed"):return
	if not await walk("pool_to_village"):return
	if not check(puzzle.state.village_released and scene.kelsrick.state.owner_state==5,"Earned return did not release village branch"):return
	if not check(scene.quicksave("user://tests/chief_hut_earned_done.json").is_empty(),"Earned completion save failed"):return
	await RenderingServer.frame_post_draw
	var directory:=evidence_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory+"/completed.png")
	var resumed: bool="--resume-chief-gate" in OS.get_cmdline_user_args()
	var scope: String="Resumed earned gate diagnostic" if resumed else "Continuous Hive-spawn fixture (initial sword supplied) through rescue, Kelsrick talk and inner gate"
	scope+=" then pool walk, armed strike, Spark, hut movie and village return; normal jumps, aimed melee, maximum Spark and Healing; no later test pose/flag/item injection."
	FileAccess.open(directory+"/proof.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":scope,"resumed_prior_gate":resumed,"jump_requests":route_jumps,"dino_strikes":dino_strikes,"healing_casts":healing_casts,"aura_casts":aura_casts,"health":scene.starting_magic.health(),"fire_save_sha256":FileAccess.get_sha256("user://tests/chief_hut_earned_fire.json"),"done_save_sha256":FileAccess.get_sha256("user://tests/chief_hut_earned_done.json"),"resets":scene.resets,"state":puzzle.checkpoint(),"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z]},"  ")+"\n")
	print("PASS chief-hut walking branch: watergate/pool, armed rock strike, actual Spark, original movie, village return and saved completion. Resumed prior earned gate: ","--resume-chief-gate" in OS.get_cmdline_user_args())
	await super.finish_inner_gate_route()
