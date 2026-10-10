extends "res://tests/jungle_aloe_use_test.gd"
## Kityara's conversation hold freezes the world except her own clip clock. Supplied conversation state (started
## through the source start group on the pure state); real Jungle host and a real dinosaur beside Luther.
## - During the hold: world_active() false, movie_world_active() true, the dinosaur deals no damage, her clip clock
##   advances, pause freezes it.
## - The 19 s timer still grants the knife once; the segment end releases Luther; then the world and the dinosaur resume.
const State=preload("res://scripts/lol2/jungle_kityara_state.gd")
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[],"equipped_item":"","equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	freeze(scene)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var k=scene.kityara;k.set_physics_process(false)
	var dinos=scene.dino_population
	var src: Dictionary=k.src
	var ctx:={"locals":{"35":1,"54":0,"23":0,"41":0},"shared":{"0":5,"14":1,"20":0,"25":0,"47":1}}
	var s:=State.initial(src)
	var start:=State.enter_region(s,src,1257,ctx)
	var restore_error: String=k.restore({"version":1,"state":s,"inside":[1257]})
	if not check(State.speaking(s)=="0" and restore_error.is_empty(),"Supplied conversation state rejected: "+restore_error+" speaking="+State.speaking(s)): return
	var pos: Array=start.filter(func(e): return e.type=="reposition")[0].position
	scene.player.global_position=Vector3(pos[0],pos[1],pos[2])+k.origin()+Vector3.UP*scene.FormBody.FOOT_OFFSET
	await physics_frame
	var id: String=dinos.bodies.keys()[0]
	dinos.bodies[id].global_position=scene.player.global_position+Vector3(30,0,0)
	await physics_frame
	scene.starting_magic.set_health(30)
	if not check(k.movement_locked() and scene.actor_input_locked() and not scene.starting_magic.world_active() and scene.starting_magic.movie_world_active() and k.live(),"Hold does not freeze the world"): return
	var t0: float=float(k.state.controls["0"].elapsed)
	for i in 180:
		dinos.advance(1.0/60.0);k.advance(1.0/60.0)
		if i%20==0: await physics_frame
	if not check(scene.starting_magic.health()==30 and float(k.state.controls["0"].elapsed)>t0+2.5,"Hostile acted or her clock stalled: health %d"%scene.starting_magic.health()): return
	var before: Dictionary=k.checkpoint()
	paused=true;k.advance(0.5);dinos.advance(0.5);paused=false
	if not check(k.checkpoint()==before and scene.starting_magic.health()==30,"Pause did not freeze her clock"): return
	for i in 40*60:
		dinos.advance(1.0/60.0);k.advance(1.0/60.0)
		if not k.movement_locked(): break
	if not check(not k.movement_locked() and scene.starting_magic.health()==30 and scene.carried_collected.count(str(src.item.catalog_id))==1 and scene._shop_local("kityara_gave_knife")==1,"Conversation did not complete safely"): return
	if not check(scene.starting_magic.world_active(),"World stayed frozen after her conversation"): return
	dinos.bodies[id].global_position=scene.player.global_position+Vector3(30,0,0)
	var bitten:=false
	for i in 360:
		dinos.advance(1.0/60.0)
		if i%20==0: await physics_frame
		if scene.starting_magic.health()<30: bitten=true;break
	if not check(bitten,"Dinosaur stayed inactive after the conversation"): return
	await finish(scene)
	print("PASS jungle_kityara_hostile_test: hold freezes world consumers (adjacent dinosaur harmless, her clock advances, pause freezes), knife once, release, world and dinosaur resume. Supplied conversation state.")
	quit()
