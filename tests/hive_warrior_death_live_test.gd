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
	scene.return_population.set_physics_process(false)
	scene.ambush_population.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	scene.starting_magic.set_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var fixture: Dictionary=scene.area_handoff()
	fixture.quests.shared_flag_38=1
	fixture.quests.hive_room_entered=true
	fixture.quests.conversation={"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
	if not check(scene.apply_area_handoff(fixture).is_empty(),"Encounter fixture rejected"): return
	scene.set_physics_process(false)
	scene.ambush_population.Ambush.arm(scene.ambush_population.state,33)
	scene.ambush_population.advance(2)
	for pair in [[scene.return_population,"27"],[scene.ambush_population,"33"]]:
		var pop=pair[0]
		var id: String=pair[1]
		var living: Dictionary=pop.checkpoint()
		var sprite: MeshInstance3D=pop.bodies[id].get_child(1)
		var texture: Texture2D=sprite.material_override.albedo_texture
		if not check(pop.receive_damage(id,500),"Warrior defeat rejected"): return
		if not check(pop.bodies[id].visible and pop.bodies[id].collision_layer==0 and not pop.targets().has(pop.target_prefix+id),"Dying warrior targeting/collision/visibility wrong"): return
		pop.advance(0.2)
		var death: Dictionary=pop.state.actors[id].death_animation
		if not check(not death.corpse and death.frame==3,"Native death frames did not advance"): return
		var path:="user://tests/warrior_death_partial.json"
		var save_error: String=scene.quicksave(path)
		if not check(save_error.is_empty(),"Partial death save failed: "+save_error): return
		var partial: Dictionary=pop.checkpoint()
		pop.advance(2)
		if not check(pop.state.actors[id].death_animation.corpse and pop.bodies[id].visible,"Death did not leave corpse"): return
		if not check(scene.quickload(path).is_empty() and pop.checkpoint()==partial,"Partial death JSON rollback failed"): return
		scene.set_physics_process(false)
		var bad: Dictionary=scene.area_handoff()
		var quest:="hive_return_population" if id=="27" else "hive_ambush"
		bad.quests[quest].actors[id].death_animation.frame=13
		var before: Dictionary=scene.area_handoff()
		if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Invalid death frame mutated save"): return
		if not check(scene.open_inventory(),"Inventory pause unavailable"): return
		pop.advance(2)
		if not check(pop.checkpoint()==partial,"Death advanced through inventory pause"): return
		scene.inventory.close()
		await process_frame
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		pop.advance(2)
		if not check(pop.state.actors[id].death_animation.corpse,"Resumed death did not finish after pause"): return
		var corpse: Dictionary=pop.checkpoint()
		pop.restore(living)
		# Settle each collider restoration before another restore/render cycle.
		await physics_frame
		if not check(sprite.material_override.albedo_texture==texture and sprite.material_override.uv1_scale==Vector3.ONE,"Living rollback kept corpse atlas"): return
		pop.restore(corpse)
		await physics_frame
		scene.camera.global_position=pop.bodies[id].global_position+Vector3(0,25,160)
		scene.camera.look_at(pop.bodies[id].global_position)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/warrior_corpse_"+id+".png")
		var legacy: Dictionary=corpse.duplicate(true)
		legacy.actors[id].erase("death_animation")
		pop.restore(legacy)
		if not check(pop.state.actors[id].death_animation.corpse,"Legacy defeated save replayed death"): return
	var handoff: Dictionary=scene.area_handoff()
	await physics_frame
	await process_frame
	await finish(scene)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	await process_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(handoff).is_empty(),"Jungle rejected warrior corpses"): return
	if not check(jungle.quicksave("user://tests/warrior_death_jungle.json").is_empty() and jungle.quickload("user://tests/warrior_death_jungle.json").is_empty(),"Jungle corpse disk roundtrip failed"): return
	var travel: Dictionary=jungle.area_handoff()
	for quest in ["hive_return_population","hive_ambush"]:
		if not check(travel.quests[quest]==handoff.quests[quest],"Jungle changed corpse clocks"): return
	await finish(jungle)
	print("PASS original warrior death frames, corpse, partial disk rollback, malformed rejection, pause, living restore, legacy migration and Jungle transport; supplied encounters")
	quit()
