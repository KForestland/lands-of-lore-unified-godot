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
	var guards=scene.get_node("Warriors")
	for pair in [[scene.return_population,"27"],[scene.ambush_population,"33"]]:
		var pop=pair[0]
		var id: String=pair[1]
		var target: CharacterBody3D=pop.bodies[id]
		var clear:=false
		for offset in [Vector3(0,32,60),Vector3(0,32,-60),Vector3(60,32,0),Vector3(-60,32,0)]:
			scene.player.position=target.position-Vector3(0,35,0)+offset
			scene.camera.look_at(target.global_position)
			await physics_frame
			var ray:=PhysicsRayQueryParameters3D.create(target.global_position,scene.camera.global_position,1,[target.get_rid(),scene.player.get_rid()])
			if scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and target.global_position.distance_to(scene.camera.global_position)<=75: clear=true;break
		if not check(clear,"No clear close attack fixture for "+id): return
		var original: Dictionary=pop.checkpoint()
		for selector in [11,12,13,14]:
			pop.restore(original)
			await physics_frame
			guards.health=30
			var actor: Dictionary=pop.state.actors[id]
			actor.attack_animation=pop.Attack.initial(selector)
			pop.present()
			pop.advance(0.2)
			if not check(actor.attack_animation.frame==3 and guards.health==30,"Attack advanced/damaged before source frame"): return
			var material: StandardMaterial3D=target.get_child(1).material_override
			if not check(material.albedo_texture!=pop.death_static[id].texture and material.uv1_scale.x<1.0 and material.uv1_offset.x>0.0,"Attack frame did not reach sprite atlas"): return
			var path:="user://tests/warrior_attack_partial.json"
			var saved: Dictionary=pop.checkpoint()
			if not check(scene.quicksave(path).is_empty(),"Attack partial save rejected"): return
			if not check(scene.open_inventory(),"Attack pause unavailable"): return
			pop.advance(100)
			if not check(pop.checkpoint()==saved and guards.health==30,"Attack advanced while paused"): return
			scene.inventory.close()
			await process_frame
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			pop.advance(100)
			var expected: int=30-{11:3,12:6,13:1,14:3}[selector]
			if not check(guards.health==expected and not pop.state.actors[id].has("attack_animation") and pop.state.actors[id].cooldown==0.8,"Source hit/terminal wrong id=%s selector=%s health=%s expected=%s actor=%s active=%s distance=%s" % [id,selector,guards.health,expected,pop.state.actors[id],pop.active(),target.global_position.distance_to(scene.camera.global_position)]): return
			pop.advance(0.1)
			if not check(guards.health==expected,"Cooldown duplicated damage"): return
			if not check(scene.quickload(path).is_empty() and pop.checkpoint()==saved and guards.health==30,"Partial attack JSON rollback failed"): return
			scene.set_physics_process(false)
			var quest:="hive_return_population" if id=="27" else "hive_ambush"
			for invalid in [{"selector":21},{"frame":pop.Attack.LAST[selector]},{"timer":1024},{"fraction":1.0},{"flags":0}]:
				var bad: Dictionary=scene.area_handoff()
				bad.quests[quest].actors[id].attack_animation.merge(invalid,true)
				var before: Dictionary=scene.area_handoff()
				if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Malformed attack mutated live save"): return
			# Finish the saved attack after the player has left its reach: no late hit.
			scene.player.position+=Vector3(0,0,200)
			await physics_frame
			pop.advance(100)
			if not check(guards.health==30 and not pop.state.actors[id].has("attack_animation"),"Missed attack damaged or did not finish"): return
			if not check(scene.quickload(path).is_empty(),"Return to close fixture failed"): return
			scene.set_physics_process(false)
			await physics_frame
			if not check(pop.receive_damage(id,500) and not pop.state.actors[id].has("attack_animation"),"Defeat retained attack state"): return
			pop.advance(100)
			if not check(guards.health==30,"Defeated warrior dealt pending attack"): return
		pop.restore(original)
		await physics_frame
		guards.health=30
		# Actual admission chooses healthy12/14; damage changes the next family to11/13.
		pop.advance(0.01)
		if not check(pop.state.actors[id].attack_animation.selector in [12,14],"Healthy source selection wrong"): return
		pop.receive_damage(id,350)
		pop.state.actors[id].erase("attack_animation")
		pop.advance(0.01)
		if not check(pop.state.actors[id].attack_animation.selector in [11,13],"Wounded source selection wrong"): return
		pop.present()
		scene.camera.look_at(target.global_position)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/warrior_attack_"+id+".png")
	var handoff: Dictionary=scene.area_handoff()
	await physics_frame
	await finish(scene)
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	await process_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(handoff).is_empty(),"Jungle rejected partial warrior attacks"): return
	if not check(jungle.quicksave("user://tests/warrior_attack_jungle.json").is_empty() and jungle.quickload("user://tests/warrior_attack_jungle.json").is_empty(),"Jungle attack disk roundtrip failed"): return
	var travel: Dictionary=jungle.area_handoff()
	for quest in ["hive_return_population","hive_ambush"]:
		if not check(travel.quests[quest]==handoff.quests[quest],"Jungle changed warrior attacks"): return
	await finish(jungle)
	print("PASS four live HIVEW attack variants for return/lower actors, timed damage, terminal stop, rollback, pause, miss, death cancellation, health selection and Jungle transport; supplied fixtures")
	quit()
