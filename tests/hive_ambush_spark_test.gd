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
	var clear:=false
	for offset in [Vector3(0,32,100),Vector3(65,32,0),Vector3(-65,32,0),Vector3(0,32,-100)]:
		scene.player.position=pop.films["35"].position+offset
		scene.camera.look_at(pop.feeding_target.global_position)
		for i in range(2): await physics_frame
		var origin: Vector3=scene.camera.global_position
		var q:=PhysicsRayQueryParameters3D.create(origin,origin-scene.camera.global_basis.z*384,11,[scene.player.get_rid()])
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider==pop.feeding_target: clear=true;break
	if not check(clear and not pop.state.contact716 and pop.state.actors["35"].phase==0,"No unarmed clear feeding fixture"): return
	var spell=scene.starting_magic
	var mana:=int(spell.magic_state().player.mana)
	if not check(spell.cast() and spell.magic_state().player.mana==mana-1,"Basic Spark failed to debit mana"): return
	if not check(pop.state.feeding_hit_disabled and pop.state.actors["35"].phase==0 and not pop.state.contact716 and pop.state.actors["35"].health==300,"Hive-specific hit suppression failed"): return
	if not check(pop.feeding_target.collision_layer==8 and not pop.receive_feeding_spark(),"Consumed feeding hit repeated"): return
	var repeat_state: Dictionary=pop.checkpoint()
	spell.magic_state().cooldown=0
	if not check(spell.cast() and pop.checkpoint()==repeat_state,"Repeated actual Spark changed the feeding sequence"): return
	var path:="user://tests/hive_feeding_spark.json"
	var before: Dictionary=pop.checkpoint()
	if not check(scene.quicksave(path).is_empty(),"Feeding-hit save rejected"): return
	pop.advance(8)
	if not check(not pop.state.actors["35"].active and pop.state.actors["35"].phase==0,"Spark incorrectly activated the Executioner"): return
	if not check(scene.quickload(path).is_empty() and pop.checkpoint()==before and pop.feeding_target.collision_layer==8,"Reload forgot consumed hit/partial film"): return
	scene.set_physics_process(false)
	var bad: Dictionary=scene.area_handoff()
	bad.quests.hive_ambush.feeding_hit_disabled=1
	if not check(not scene.apply_area_handoff(bad).is_empty() and pop.checkpoint()==before,"Invalid consumed flag changed live state"): return
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	await physics_frame
	if not check(jungle.apply_area_handoff(scene.area_handoff()).is_empty(),"Feeding-hit Jungle transport rejected"): return
	if not check(jungle.quicksave("user://tests/hive_feeding_spark_jungle.json").is_empty() and jungle.quickload("user://tests/hive_feeding_spark_jungle.json").is_empty(),"Feeding-hit Jungle disk roundtrip rejected"): return
	if not check(scene.apply_area_handoff(jungle.area_handoff()).is_empty() and pop.checkpoint()==before and not pop.receive_feeding_spark(),"Travel retriggered the feeding hit"): return
	jungle.queue_free()
	await process_frame
	# The original first-contact region must still activate after the rejected hit.
	var region: Dictionary=pop.data.regions.filter(func(r): return int(r.region)==716)[0]
	var center:=Vector2.ZERO
	for p in region.polygon: center+=Vector2(p[0],p[1])
	center/=region.polygon.size()
	scene.player.position=Vector3(center.x,float(region.floor)+32,center.y)
	for i in range(8):
		await physics_frame
		scene.player.velocity=Vector3(0,-30,0);scene.player.move_and_slide()
	pop.approach()
	if not check(pop.state.actors["35"].phase==1 and pop.state.contact716,"Region did not activate after rejected hit"): return
	pop.advance(8)
	if not check(pop.state.actors["35"].active and pop.feeding_target.collision_layer==0,"Region film handoff failed after rejected hit"): return
	print("PASS aimed Spark prop318 suppression, mana, consumed history, reload/Jungle and later region activation")
	quit()
