extends "res://tests/player_magic_handoff_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	scene.hive_curse.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	scene.return_population.set_physics_process(false)
	scene.starting_magic.set_process(false)
	scene.item_effects.set_process(false)
	var pop=scene.return_population
	if not check(pop.targets().is_empty(),"Initial visit spawned reinforcements"): return
	var fixture: Dictionary=scene.area_handoff()
	fixture.quests.shared_flag_38=1
	fixture.quests.hive_room_entered=true
	fixture.quests.conversation={"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
	if not check(scene.apply_area_handoff(fixture).is_empty() and pop.targets().size()==3,"Rescue return did not activate three warriors"): return
	scene.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var guards=scene.get_node("Warriors")
	var spells=scene.starting_magic
	var target: CharacterBody3D=pop.bodies["27"]
	var clear:=false
	for offset in [Vector3(0,32,65),Vector3(0,32,-65),Vector3(65,32,0),Vector3(-65,32,0)]:
		scene.player.position=pop.State.SPAWNS[27]+offset
		scene.camera.look_at(target.global_position)
		for i in range(2): await physics_frame
		var hit: Dictionary=guards.aimed_hit()
		if not hit.is_empty() and hit.collider==target: clear=true;break
	if not check(clear,"Source warrior has no clear attack fixture"): return
	guards._process(0)
	spells._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/hive_return_warrior.png")
	var struck: bool=guards.strike()
	if not check(struck and pop.state.actors["27"].health==396 and not scene.player_reward_checkpoint.is_empty(),"Aimed melee/reward failed"): return
	if not check(spells.cast() and pop.state.actors["27"].health==388 and spells.magic_state().player.experience>0,"Aimed Spark/reward failed"): return
	if not check(not scene.get_node("QuestPillar").moving,"Return warrior triggered guardian pillar"): return
	spells.magic_state().cooldown=0
	if not check(spells.cast(5) and spells.protected(),"Maximum Spark unavailable"): return
	pop.advance(1.2)
	if not check(guards.health==1,"Return warrior bypassed aura protection"): return
	spells.aura.advance(0.5)
	if not check(pop.state.actors["27"].health<388,"Aura did not target return warrior"): return
	var path:="user://tests/hive_population.json"
	var before: Dictionary=scene.area_handoff()
	if not check(scene.quicksave(path).is_empty(),"Population save failed"): return
	if not check(pop.receive_damage("27",400) and pop.state.actors["27"].health==0 and target.collision_layer==0,"Defeat/collision failed"): return
	if not check(scene.quickload(path).is_empty() and scene.area_handoff()==before and target.collision_layer==2,"Combat JSON rollback failed"): return
	scene.set_physics_process(false)
	# A ray-verified source approach, separate from the close melee fixture.
	var pursued:=false
	for id in ["27","28","29"]:
		var chaser: CharacterBody3D=pop.bodies[id]
		var start_position: Vector3=chaser.position
		for angle in range(8):
			var direction:=Vector3(cos(angle*PI/4),0,sin(angle*PI/4))
			scene.player.position=pop.State.SPAWNS[int(id)]+direction*100+Vector3(0,32,0)
			scene.camera.look_at(chaser.global_position)
			await physics_frame
			var ray:=PhysicsRayQueryParameters3D.create(chaser.global_position,scene.camera.global_position,1,[chaser.get_rid(),scene.player.get_rid()])
			if not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			for i in range(30):
				await physics_frame
				pop.advance(1.0/60.0)
			if chaser.position.distance_to(start_position)>1: pursued=true;break
		if pursued: break
	if not check(pursued,"No tested source warrior pursued on a clear approach"): return
	var pursued_state: Dictionary=pop.checkpoint()
	if not check(scene.quicksave("user://tests/hive_population_pursued.json").is_empty() and scene.quickload("user://tests/hive_population_pursued.json").is_empty() and pop.checkpoint()==pursued_state,"Post-pursuit JSON position rollback failed"): return
	scene.set_physics_process(false)
	if not check(scene.quickload(path).is_empty() and pop.checkpoint()==before.quests.hive_return_population,"Pursuit position rollback failed"): return
	scene.set_physics_process(false)
	spells.cancel_aura()
	guards.health=30
	pop.state.actors["27"].windup=0.0
	pop.state.actors["27"].cooldown=0.0
	var attack_seed: int=(1103515245*int(pop.state.actors["27"].seed)+12345)&0x7fffffff
	var selected: Dictionary=pop.Selection.select(5,pop.state.actors["27"].get("warrior_mask",1),0,attack_seed%101)
	var expected_health: int=30-{11:3,12:6,13:1,14:3}[int(selected.selector)]
	pop.advance(1.2)
	if not check(guards.health==expected_health,"Return warrior source-percent attack failed"): return
	if not check(scene.open_inventory(),"Pause inventory failed"): return
	var paused_state: Dictionary=pop.checkpoint()
	pop.advance(3)
	if not check(pop.checkpoint()==paused_state and guards.health==expected_health,"Inventory allowed hostile update"): return
	scene.inventory.close()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(pop.receive_damage("27",400),"Defeat for travel failed"): return
	before=scene.area_handoff()
	var bad: Dictionary=before.duplicate(true)
	bad.quests.hive_return_population.actors["27"].health=-1
	if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Malformed population mutated state"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and pop.state.actors["27"].health==0,"Saved defeat respawned"): return
	before=scene.area_handoff()
	await finish(scene)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene=jungle
	await process_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(before).is_empty(),"Jungle rejected population"): return
	if not check(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty(),"Jungle population disk save failed"): return
	var travel: Dictionary=jungle.area_handoff()
	if not check(travel.quests.hive_return_population==before.quests.hive_return_population,"Jungle changed population"): return
	# The second source quest is supplied separately to isolate its admission.
	travel.quests.monastery.globals.GV_MET_BACATTA=1
	await finish(jungle)
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	if not check(scene.apply_area_handoff(travel).is_empty(),"Return admission failed"): return
	pop=scene.return_population
	pop.set_physics_process(false)
	scene.set_physics_process(false)
	if not check(pop.targets().size()==6 and pop.state.actors["27"].health==0 and pop.state.actors["23"].health==400,"Bacatta four-warrior activation or defeated persistence failed"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and pop.targets().size()==6,"Second-wave save failed"): return
	await finish(scene)
	DirAccess.remove_absolute(path)
	print("PASS source return groups3+4, aimed melee/Spark/XP, aura targeting/protection, attack/pause, defeat/collision, disk rollback, Jungle transport and no respawn; supplied quest/combat fixtures")
	quit()
