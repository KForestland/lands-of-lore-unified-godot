extends SceneTree
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/cave_captain_"+name+".png")
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready,"Captain cave ready"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false);scene.guard_population.set_physics_process(false);scene.wild_roach_population.set_physics_process(false);scene.roach_population_live.set_process(false)
	var captain=scene.captain;captain.set_physics_process(false)
	scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var plate: Dictionary=captain.media.plates[0]
	scene.player.global_position=Vector3(plate.position[0],plate.height+34,plate.position[2])+scene.native_translation
	for i in range(30):
		scene.player.velocity=Vector3(0,-30,0);scene.player.move_and_slide();await physics_frame
		captain.advance(1.0/60.0)
		if captain.intro_active():break
	if not check(captain.intro_active() and captain.state.contact.owner==89 and not captain.state.source.captain.present,"Actual grounded plate89 starts original intro"):return
	if not check(not scene.starting_magic.world_active(),"Intro blocks player magic"):return
	for i in range(90):captain.advance(1.0/60.0)
	var save:="user://tests/cave_captain_live.json"
	var save_error: String=scene._quicksave(save)
	if not check(save_error.is_empty(),"Partial intro disk save: "+save_error):return
	var partial: Dictionary=captain.checkpoint();await capture("intro")
	paused=true;captain.advance(1);await process_frame;await process_frame
	if not check(captain.checkpoint()==partial and captain.voice.stream_paused,"Intro clocks and voice pause"):return
	paused=false
	for i in range(700):captain.advance(1.0/60.0)
	if not check(captain.state.movie_done and captain.state.source.captain.present and captain.state.source.captain.state==5 and captain.fighting(),"Original intro endpoint spawns fighting captain"):return
	var load_error: String=scene._quickload(save)
	if not check(load_error.is_empty() and captain.checkpoint()==partial,"Partial intro exact disk rollback"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	for i in range(700):captain.advance(1.0/60.0)
	# Stage the captain south of953, then let the production pursuit/collision step cross its source boundary.
	var row: Dictionary=captain.media.regions[0];var centre:=Vector2.ZERO
	for p in row.polygon:centre+=Vector2(p[0],p[1])
	centre/=row.polygon.size()
	var body: CharacterBody3D=scene.guard_population.bodies["56"]
	scene.player.global_position=Vector3(centre.x,47.5+32,centre.y)+scene.native_translation
	captain.own_region()
	if not check(captain.state.source.captain.state==5,"Player entering953 cannot surrender captain"):return
	body.global_position=Vector3(centre.x,45,-4290)+scene.native_translation
	scene.guard_population.state.actors["56"].position=[centre.x,45,-4290]
	await physics_frame
	for i in range(480):
		scene.guard_population.advance(1.0/60.0)
		if captain.state.source.captain.state==0:break
		await physics_frame
	if captain.state.source.captain.state!=0:print("WALK end ",body.global_position-scene.native_translation," live ",scene.guard_population.state.live["56"])
	scene.starting_magic.set_health(30)
	if not check(captain.state.source.captain.state==0 and captain.state.region==953,"Captain own source region admission"):return
	if not check(scene.guard_population.receive_damage("56",1,true,20) and captain.state.source.captain.state==0,"Melee fails surrender mask"):return
	var viewed:=false
	for angle in range(0,360,15):
		var p: Vector3=body.global_position+Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*70
		var down:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*80,p-Vector3.UP*100,1)
		var floor_hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(down)
		if floor_hit.is_empty():continue
		scene.player.global_position=floor_hit.position+Vector3.UP*34;scene.camera.look_at(body.global_position+Vector3.UP*24);await physics_frame
		if scene.guard_population.aimed()=="56":viewed=true;break
	if not check(viewed,"Production ray sees captain in source surrender region"):return
	scene.starting_magic.select_spell("spark")
	if not check(scene.starting_magic.cast(1),"Actual Spark cast on captain"):return
	if not check(captain.state.source.captain.state==1 and captain.state.source.captain.health==0 and captain.state.source.locals["50"]==10 and captain.state.source.captain.items.is_empty(),"Source mode2 outcome0HP and no fighting sword loot"):return
	var heard_source_cue:=false
	for i in range(300):
		scene.guard_population.advance(1.0/60.0);captain.advance(1.0/60.0)
		var request: int=scene.guard_population.state.audio["56"].request
		if request==439:heard_source_cue=true
		if not check(request!=627,"Surrender cannot play generic death8 voice"):return
	if not check(heard_source_cue,"Original selector10 frame3 cue439"):return
	if not check(captain.state.source.captain.state==2 and captain.state.source.captain.selector==11,"Original surrender pose endpoint"):return
	await capture("surrender")
	if not check(captain.use() and captain.use(),"Actual aimed use twice on surrendered0HP actor"):return
	if not check(captain.state.source.granted==["5-Short swd","37-Brnt Chain"] and preload("res://scripts/lol2/cave_captain_items.gd").ARMOR in scene.carried_items(),"Source items enter carried inventory"):return
	for i in range(90):captain.advance(1.0/60.0)
	if not check(captain.state.speech>0 and captain.speech.playing and (captain.state.source.timer.flags&1)==1,"Original timer speech1031"):return
	var speech_partial: Dictionary=captain.checkpoint()
	paused=true;captain.advance(1);await process_frame;await process_frame
	if not check(captain.checkpoint()==speech_partial and captain.speech.stream_paused,"Timer speech pause"):return
	paused=false
	if not check(scene._quicksave(save).is_empty(),"Surrendered item scene save validates"):return
	var terminal: Dictionary=captain.checkpoint()
	load_error=scene._quickload(save)
	if not check(load_error.is_empty() and captain.checkpoint()==terminal,"Surrender save rollback"):return
	var malformed: Dictionary=captain.checkpoint();malformed.receipts=["bad"]
	if not check(not captain.validate(malformed).is_empty(),"Malformed receipt rejected"):return
	malformed=captain.checkpoint();malformed.movie=NAN
	if not check(not captain.validate(malformed).is_empty(),"Malformed movie clock rejected"):return
	print("PASS cave captain real plate→original intro/audio/pause/partial save→source fight spawn; captain physically pursues across own region953 (player entry excluded)→actual Spark→0HP surrender/no fight loot→pose endpoint→two aimed uses/source sword+chain→original timer speech→scene save")
	scene.queue_free();await process_frame;await process_frame;quit()
