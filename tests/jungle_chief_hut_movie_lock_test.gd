extends "res://tests/jungle_aloe_use_test.gd"
## The fullscreen hut movie freezes the world except its own clock. Supplied movie state; real Jungle host and a real
## dinosaur beside Luther (not a route).
## - During the movie: world_active() is false, the puzzle's own owner check stays true, the adjacent dinosaur deals
##   no damage, the movie clock advances, and pause freezes it.
## - The movie completes into its source outcomes (soul -1 once, Kelsrick local8 200) and releases the player.
## - After release the world is active again and the same dinosaur can bite.
const State=preload("res://scripts/lol2/jungle_chief_hut_state.gd")
func movie_state(src: Dictionary) -> Dictionary:
	var s:=State.initial()
	State.raise_gate(s,src,2);State.observe_pool(s,src);State.advance(s,src,1)
	State.strike(s,src);State.advance(s,src,0.5);State.ignite(s,src)
	for i in 600:
		State.advance(s,src,1.0/30)
		if s.phase=="movie": break
	return s
func run() -> void:
	var src:=State.source()
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var puzzle=scene.chief_hut;puzzle.set_physics_process(false)
	var dinos=scene.dino_population
	var movie:=movie_state(src)
	if not check(movie.phase=="movie" and puzzle.restore(movie).is_empty(),"Supplied movie state rejected"): return
	var id: String=dinos.bodies.keys()[0]
	scene.player.global_position=Vector3(-2935,0,-5060)+puzzle.origin()+Vector3.UP*scene.FormBody.FOOT_OFFSET
	await physics_frame
	dinos.bodies[id].global_position=scene.player.global_position+Vector3(30,0,0)
	await physics_frame
	scene.starting_magic.set_health(30)
	if not check(puzzle.input_locked() and not scene.starting_magic.world_active() and scene.starting_magic.movie_world_active() and puzzle.live(),"Movie lock does not freeze the world"): return
	var soul: int=scene._kelsrick_context().shared["0"]
	var t0: float=float(puzzle.state.movie_elapsed)
	for i in 120:
		dinos.advance(1.0/60.0);puzzle.advance(1.0/60.0)
		if i%20==0: await physics_frame
	if not check(scene.starting_magic.health()==30 and float(puzzle.state.movie_elapsed)>t0+1.5 and puzzle.state.phase=="movie","Hostile acted or movie clock stalled during the movie: health %d"%scene.starting_magic.health()): return
	var before_pause: Dictionary=puzzle.checkpoint()
	paused=true;puzzle.advance(0.5);dinos.advance(0.5);paused=false
	if not check(puzzle.checkpoint()==before_pause and scene.starting_magic.health()==30,"Pause did not freeze the movie"): return
	for i in 240:
		dinos.advance(1.0/60.0);puzzle.advance(1.0/60.0)
		if puzzle.state.phase=="done": break
	if not check(puzzle.state.phase=="done" and not puzzle.overlay.visible and not scene.actor_input_locked() and scene.starting_magic.health()==30,"Movie did not complete and release"): return
	if not check(scene._kelsrick_context().shared["0"]==maxi(0,soul-1) and scene.kelsrick.local_value(8)==200,"Movie outcome differs"): return
	if not check(scene.starting_magic.world_active(),"World stayed frozen after the movie"): return
	dinos.bodies[id].global_position=scene.player.global_position+Vector3(30,0,0)
	var bitten:=false
	for i in 360:
		dinos.advance(1.0/60.0)
		if i%20==0: await physics_frame
		if scene.starting_magic.health()<30: bitten=true;break
	if not check(bitten,"Dinosaur stayed inactive after the movie"): return
	await finish(scene)
	print("PASS hut movie freezes world consumers (adjacent dinosaur harmless, movie clock advances, pause freezes), completes once into soul/Kelsrick outcomes, then the world and the dinosaur resume. Supplied movie state.")
	quit()
