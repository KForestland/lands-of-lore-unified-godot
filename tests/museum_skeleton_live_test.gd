extends SceneTree
const State=preload("res://scripts/lol2/museum_skeleton_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
# Headless display cannot capture the mouse; only the world gate is replaced.
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var running:=true
	func world_active() -> bool: return running
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func step(pop, seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		pop.advance(1.0/60.0)
		await physics_frame
func run() -> void:
	set_meta("lol2_cave_completion",{"collected":["cave:prop641:harvest1:Stalagmite"],"equipped_item":"cave:prop641:harvest1:Stalagmite","health":30})
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum);current_scene=museum
	for i in range(5): await process_frame
	museum.set_physics_process(false)
	var pop=museum.skeleton_population
	if not check(pop!=null and pop.bodies.size()==13 and pop.targets().size()==11 and not pop.bodies["30"].visible,"Museum creatures missing or absent actors shown"):return
	pop.set_physics_process(false)
	museum.starting_magic.set_process(false)
	var spells:=TestMagic.new();museum.add_child(spells);spells.set_process(false);museum.starting_magic=spells
	if not check(not pop.state.actors["24"].woken and not State.ready_to_fight(pop.state,pop.src,"24"),"Exhibit skeleton not dormant"):return
	# Dormant skeletons ignore a nearby player.
	var body: CharacterBody3D=pop.bodies["25"]
	museum.player.global_position=body.global_position+Vector3(0,32,60)
	await physics_frame
	await step(pop,1.0)
	if not check(pop.state.live["25"].mode==Live.IDLE and museum.health==30,"Dormant skeleton acted"):return
	# Walking into source region35 wakes 24/25/26 (property13/7), which rise and fight.
	var r35: Dictionary=pop.src.regions.filter(func(x):return int(x.region)==35)[0]
	var c:=Vector2.ZERO
	for v in r35.polygon: c+=Vector2(v[0],v[1])
	c/=r35.polygon.size()
	var down:=PhysicsRayQueryParameters3D.create(Vector3(c.x,float(r35.floor_max)+40,c.y),Vector3(c.x,float(r35.floor_min)-40,c.y),1)
	var hit: Dictionary=pop.get_world_3d().direct_space_state.intersect_ray(down)
	if not check(not hit.is_empty(),"Region35 floor missing"):return
	museum.player.global_position=hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	museum.player.velocity=Vector3.DOWN*10
	museum.player.move_and_slide()
	await physics_frame
	if not check(museum.player.is_on_floor(),"Player not grounded in region35"):return
	pop.advance(1.0/60.0)
	if not check(pop.state.regions==[35] and pop.state.actors["24"].woken and pop.state.actors["26"].woken and not pop.state.actors["27"].woken,"Region35 wake differs"):return
	var waited:=0.0
	while museum.health==30 and waited<15.0:
		await step(pop,0.25);waited+=0.25
	if not check(museum.health<30 and (30-museum.health)%3==0,"Skeleton damage differs: %d"%museum.health):return
	var path:="user://tests/museum_skeleton_live.json"
	museum.health=30
	if not check(museum.quicksave(path).is_empty(),"Museum save failed"):return
	var saved: Dictionary=pop.checkpoint()
	await step(pop,1.0)
	if not check(museum.quickload(path).is_empty() and pop.checkpoint()==saved and museum.health==30,"Museum skeleton disk rollback failed"):return
	museum.set_physics_process(false)
	# Melee through the production strike earns fighting XP (scale2).
	var target: CharacterBody3D=pop.bodies["24"]
	museum.player.global_position=target.global_position+Vector3(0,32,55)
	museum.camera.look_at(target.global_position+Vector3(0,24,0))
	await physics_frame
	var xp_before: Dictionary=museum.fighting_checkpoint.duplicate(true)
	var hp: int=pop.state.actors["24"].health
	if not check(pop.aimed()=="24" and pop.strike() and pop.state.actors["24"].health<hp and museum.fighting_checkpoint!=xp_before,"Melee strike/XP failed"):return
	# Spark through the shared collider dispatch.
	spells.select_spell("spark")
	hp=pop.state.actors["24"].health
	if not check(spells.cast() and pop.state.actors["24"].health==hp-8,"Spark did not hit skeleton"):return
	# Ten counted deaths leave prop93 unchanged, persisted through a disk save.
	var Control96=preload("res://scripts/lol2/museum_control96_state.gd")
	Control96.admit(museum.control96.state) # supplied visibility event for this combat fixture
	for effect in Control96.advance(museum.control96.state,5.0):
		if effect=="spawn30": State.spawn(pop.state,"30")
	for id in ["23","24","25","26","27","28","29","30","31","32"]: pop.receive_damage(id,999,false)
	if not check(pop.state.counter==10 and pop.state.prop93==0 and pop.targets().size()==2,"Counter/prop93 differs"):return
	museum.player.global_position=Vector3(981,60,-2400)
	museum.health=30
	var counter_save: String=museum.quicksave(path)
	var counter_load: String=museum.quickload(path) if counter_save.is_empty() else "not loaded"
	if not check(counter_save.is_empty() and counter_load.is_empty() and pop.state.prop93==0,"Counter disk rollback failed: "+counter_save+" / "+counter_load):return
	museum.health=0
	var event:=InputEventKey.new();event.keycode=KEY_R;event.pressed=true
	pop._unhandled_input(event)
	if not check(museum.health==30,"Retry did not recover"):return
	DirAccess.remove_absolute(path)
	print("PASS: 13 Museum creatures; dormant until source region35 wake; rise/fight scaled3/6 hits; disk rollback; melee XP; Spark; ten-death counter without synthetic prop93 state; retry")
	remove_meta("lol2_cave_completion")
	museum.queue_free()
	await process_frame
	quit()
