extends SceneTree
const Population=preload("res://scripts/lol2/cave_lurking_roach.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	if not check(scene.walkthrough_ready,"Cave load failed"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	var pop=scene.lurking_roach_population
	if not check(is_instance_valid(pop),"Production pair setup failed"):return
	pop.set_physics_process(false)
	scene.starting_magic.set_process(false)
	var magic:=TestMagic.new();scene.add_child(magic);magic.set_process(false);magic.host=scene;scene.starting_magic=magic
	scene.stalagmites.collected=["cave:prop641:harvest1:Stalagmite"];scene.equipped_item="cave:prop641:harvest1:Stalagmite"
	for id in ["36","37"]:
		if not check(pop.state.actors[id].health==150 and pop.bodies[id].visible and pop.targets().has("cavelurkingroach"+id),"Source presence/target identity differs"):return
		var aimed:=false
		for angle in range(0,360,30):
			scene.player.global_position=pop.bodies[id].global_position+Vector3(sin(deg_to_rad(angle))*35,32,cos(deg_to_rad(angle))*35)
			scene.camera.look_at(pop.bodies[id].global_position+Vector3(0,6,0));await physics_frame
			if pop.aimed()==id: aimed=true;break
		if not check(aimed,"Source actor inaccessible to actual melee ray "+id):return
		var near_position: Vector3=scene.player.global_position
		var away: Vector3=near_position-pop.bodies[id].global_position
		scene.player.global_position=pop.bodies[id].global_position+Vector3(away.x*3,away.y,away.z*3)
		var before_position: Vector3=pop.bodies[id].global_position
		pop.advance(0.1)
		if not check(int(pop.state.live[id].mode)==1 and pop.bodies[id].global_position.distance_to(scene.player.global_position)<before_position.distance_to(scene.player.global_position),"Native goal5 chase did not move toward player"):return
		scene.player.global_position=near_position
		magic.set_health(100)
		pop.advance(0.01)
		if not check(int(pop.state.live[id].mode)==2,"Reach-admitted native AA2 did not begin attack"):return
		var attack_saved: Dictionary=pop.checkpoint()
		if not check(pop.restore(JSON.parse_string(JSON.stringify(attack_saved))).is_empty(),"Attack checkpoint failed"):return
		pop.advance(9.0/8.0)
		if not check(magic.health()==94,"First original15-request hit did not apply playable6 damage"):return
		pop.advance(3.0/8.0)
		if not check(magic.health()==88,"Second original15-request hit did not apply playable6 damage"):return
		pop.recover()
		if not check(pop.aimed()==id and pop.strike() and pop.state.actors[id].health==142,"Actual aimed melee failed"):return
		var saved: Dictionary=pop.checkpoint()
		if not check(pop.receive_damage(id,999) and pop.state.actors[id].health==0,"Defeat failed"):return
		pop.advance(4.0)
		if not check(pop.creature_audio.pose(id).selector==9 and pop.bodies[id].collision_layer==0,"Original corpse/audio pose failed"):return
		if not check(pop.restore(JSON.parse_string(JSON.stringify(saved))).is_empty() and pop.state.actors[id].health==142,"Checkpoint rollback failed"):return
		var bad: Dictionary=saved.duplicate(true);bad.actors[id].health=151
		if not check(not pop.restore(bad).is_empty() and pop.state.actors[id].health==142,"Invalid restore mutated pair"):return
		pop.strike_remaining=0.0
	if not check(scene.quest_state.has("player_reward_state"),"Missing source-scale fighting reward"):return
	print("PASS cave_lurking_roach_live_test: actual cave source-present pair, aimed melee/reward, original corpse/audio, rollback; native-bound chase/attack adapter")
	scene.queue_free();await process_frame;quit()
