extends SceneTree
const State=preload("res://scripts/lol2/scripted_creature_state.gd")
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
func stand_in(scene, pop, index: int) -> bool:
	var region: Dictionary=pop.src.regions.filter(func(x):return int(x.region)==index)[0]
	var c:=Vector2.ZERO
	for v in region.polygon: c+=Vector2(v[0],v[1])
	c/=region.polygon.size()
	var t: Vector3=scene.native_translation
	var down:=PhysicsRayQueryParameters3D.create(Vector3(c.x,float(region.floor_max)+40,c.y)+t,Vector3(c.x,float(region.floor_min)-40,c.y)+t,1)
	var hit: Dictionary=pop.get_world_3d().direct_space_state.intersect_ray(down)
	if hit.is_empty(): return false
	scene.player.global_position=hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	scene.player.velocity=Vector3.DOWN*10;scene.player.move_and_slide()
	await physics_frame
	return scene.player.is_on_floor()
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready and scene.guard_population!=null,"Cave guards not loaded"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	var pop=scene.guard_population
	pop.set_physics_process(false);scene.roach_population_live.set_process(false)
	if not check(pop.targets().keys()==["caveguard52"] and not pop.bodies["39"].visible,"Only guard52 should start present"):return
	if not check(await stand_in(scene,pop,769),"Region769 floor"):return
	pop.advance(1.0/60.0)
	if not check(pop.state.controls["109"]==1 and not pop.state.actors["39"].present and not pop.bodies["39"].visible,"Region769 must disarm control109 without spawning guard39"):return
	if not check(pop.aimed_control().is_empty(),"State-only cave control must not offer Museum use interaction"):return
	if not check(await stand_in(scene,pop,1104),"Region1104 floor"):return
	pop.advance(1.0/60.0)
	if not check(pop.state.regions==[769,1104] and pop.state.actors["52"].woken and pop.state.controls["114"]==1,"Region1104 did not wake guard52 and disarm control114"):return
	# Step into the guard's view, as a player walking on would.
	var gb: CharacterBody3D=pop.bodies["52"]
	var seen:=false
	for angle in range(0,360,30):
		var offset:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*120
		var down:=PhysicsRayQueryParameters3D.create(gb.global_position+offset+Vector3.UP*60,gb.global_position+offset-Vector3.UP*60,1)
		var fh: Dictionary=pop.get_world_3d().direct_space_state.intersect_ray(down)
		if fh.is_empty(): continue
		var stand: Vector3=fh.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		var los:=PhysicsRayQueryParameters3D.create(gb.global_position+Vector3.UP*36,stand+Vector3.UP*8,1,[gb.get_rid(),scene.player.get_rid()])
		if pop.get_world_3d().direct_space_state.intersect_ray(los).is_empty():
			scene.player.global_position=stand;seen=true;break
	if not check(seen,"No visible standing spot near guard52"):return
	await physics_frame
	var waited:=0.0
	var model=scene.roach.model
	while model.player_health==30 and waited<20.0:
		await step(pop,0.25);waited+=0.25
	if not check(model.player_health<30 and (30-model.player_health)%6==0,"Guard damage differs: %d"%model.player_health):return
	model.player_health=30
	var path:="user://tests/cave_guard_live.json"
	if not check(scene._quicksave(path).is_empty(),"Cave guard save failed"):return
	var saved: Dictionary=pop.checkpoint()
	await step(pop,1.0)
	if not check(scene._quickload(path).is_empty() and pop.checkpoint()==saved,"Cave guard disk rollback failed"):return
	scene.set_physics_process(false)
	# Melee through the production strike: fighting XP goes to the cave quest_state.
	var body: CharacterBody3D=pop.bodies["52"]
	scene.player.global_position=body.global_position+Vector3(0,32,50)
	scene.camera.look_at(body.global_position+Vector3(0,24,0))
	scene.flying=false
	await physics_frame
	scene.equipped_item="cave:prop641:harvest1:Stalagmite"
	scene.stalagmites.collected=["cave:prop641:harvest1:Stalagmite"]
	pop.strike_remaining=0.0
	var hp: int=pop.state.actors["52"].health
	if not check(pop.aimed()=="52" and pop.strike() and pop.state.actors["52"].health<hp and scene.quest_state.has("player_reward_state"),"Guard melee/XP failed"):return
	# Region1941 spawns guard38, which appears and then fights without another wake.
	if not check(await stand_in(scene,pop,1941),"Region1941 floor"):return
	pop.advance(1.0/60.0)
	if not check(pop.state.actors["38"].present and pop.bodies["38"].visible and pop.targets().has("caveguard38"),"Region1941 did not spawn guard38"):return
	await step(pop,2.0)
	if not check(State.ready_to_fight(pop.state,pop.src,"38"),"Spawned guard38 not ready"):return
	if not check(pop.receive_damage("38",999,false) and pop.state.actors["38"].health==0,"Guard38 defeat failed"):return
	DirAccess.remove_absolute(path)
	print("PASS: cave guards present/absent by source flag; region1104 wake, rise and playable6 hits; disk rollback; melee XP to cave fighting state; region1941 spawn; defeat")
	scene.queue_free()
	await process_frame
	quit()
