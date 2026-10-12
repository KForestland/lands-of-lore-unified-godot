extends "res://tests/player_magic_handoff_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene);current_scene=scene
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
	var pop=scene.ambush_population
	pop.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(pop.targets().is_empty(),"Ambush actors active before source trigger"): return
	for region_id in [444,716]:
		var region: Dictionary=pop.data.regions.filter(func(r): return int(r.region)==region_id)[0]
		var center:=Vector2.ZERO
		for p in region.polygon: center+=Vector2(p[0],p[1])
		center/=region.polygon.size()
		scene.player.position=Vector3(center.x,float(region.floor)+32,center.y)
		for i in range(8):
			await physics_frame
			scene.player.velocity=Vector3(0,-30,0)
			scene.player.move_and_slide()
		pop.approach()
		var id:="33" if region_id==444 else "35"
		if not check(pop.state.actors[id].phase==1,"Source region did not arm actor "+id): return
		if not check(pop.films[id].visible and not pop.bodies[id].visible,"Actor replaced film too early"): return
		pop.advance(0.5)
		scene.camera.look_at(pop.films[id].global_position+Vector3(0,20,0))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/hive_ambush_film_"+id+".png")
		var path:="user://tests/hive_ambush_partial.json"
		var before: Dictionary=pop.checkpoint()
		var save_error: String=scene.quicksave(path)
		if not check(save_error.is_empty(),"Partial ambush save rejected: "+save_error): return
		pop.advance(8.0)
		if not check(pop.state.actors[id].active,"Film never enabled actor"): return
		if not check(scene.quickload(path).is_empty() and pop.checkpoint()==before,"Partial ambush JSON rollback failed"): return
		scene.set_physics_process(false)
		pop.advance(8.0)
		if not check(pop.state.actors[id].active and not pop.films[id].visible and pop.bodies[id].visible,"Film-to-actor handoff failed"): return
		var guards=scene.get_node("Warriors")
		var spells=scene.starting_magic
		var target: CharacterBody3D=pop.bodies[id]
		var clear:=false
		for offset in [Vector3(0,32,65),Vector3(0,32,-65),Vector3(65,32,0),Vector3(-65,32,0)]:
			scene.player.position=pop.Ambush.SPAWNS[int(id)]+offset
			scene.camera.look_at(target.global_position)
			for i in range(2): await physics_frame
			var hit: Dictionary=guards.aimed_hit()
			if not hit.is_empty() and hit.collider==target: clear=true;break
		if not check(clear,"No clear aimed attack on ambush "+id): return
		guards.cooldown=0
		var hp:=int(pop.state.actors[id].health)
		if not check(guards.strike() and pop.state.actors[id].health==hp-4,"Ambush aimed melee failed"): return
		spells.magic_state().cooldown=0
		if not check(spells.cast() and pop.state.actors[id].health==hp-12,"Ambush basic Spark failed"): return
		guards._process(0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/hive_ambush_"+id+".png")
		spells.magic_state().cooldown=0
		if not check(spells.cast(5),"Ambush maximum Spark rejected"): return
		var aura_hp:=int(pop.state.actors[id].health)
		pop.advance(1.2)
		if not check(guards.health==1,"Ambush bypassed aura protection"): return
		spells.aura.advance(1.1)
		if not check(pop.state.actors[id].health<aura_hp,"Aura did not hit ambush target "+id): return
		if not check(pop.receive_damage(id,1000) and target.collision_layer==0,"Ambush defeat failed"): return
	var saved: Dictionary=scene.area_handoff()
	if not check(scene.quicksave("user://tests/hive_ambush_defeated.json").is_empty(),"Defeated ambush save rejected"): return
	var bad: Dictionary=saved.duplicate(true)
	bad.quests.hive_ambush.local7=0
	if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==saved,"Malformed ambush changed live state"): return
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	await physics_frame
	if not check(jungle.apply_area_handoff(saved).is_empty(),"Ambush travel to Jungle rejected"): return
	if not check(jungle.quicksave("user://tests/hive_ambush_jungle.json").is_empty() and jungle.quickload("user://tests/hive_ambush_jungle.json").is_empty(),"Jungle JSON ambush save rejected"): return
	if not check(scene.apply_area_handoff(jungle.area_handoff()).is_empty() and pop.targets().is_empty() and pop.state.actors["33"].health==0 and pop.state.actors["35"].health==0,"Travel respawned defeated ambush actors"): return
	jungle.queue_free()
	await process_frame
	print("PASS source-region ambushes, film handoff, aimed melee/Spark, partial JSON, defeat and Jungle persistence")
	quit()
