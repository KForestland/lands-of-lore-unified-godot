extends SceneTree
## Fixture positions, production aimed-hit/strike and target health paths.
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_physics_process(false)
	var guards=scene.get_node("Warriors")
	var live=scene.executioner_live
	var nest=scene.get_node("Nest")
	guards.set_process(false)
	live.set_physics_process(false)
	nest.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for target in ["guardian","executioner"]:
		if target=="guardian":
			scene.player.position=guards.POSITIONS[0]+Vector3(0,32,65)
			scene.camera.look_at(guards.POSITIONS[0]+Vector3(0,35,0))
		else:
			nest.chasm_handoff()
			live.advance(0.01)
			scene.player.position=live.SPAWN+Vector3(0,32,65)
			scene.camera.look_at(live.body.global_position)
		for tick in range(3): await physics_frame
		for id in ["","cave:captain:Short_Sword","cave:prop641:harvest1:Stalagmite","museum:item11:Fine_Longsword"]:
			scene.carried_inventory={"collected":[] if id.is_empty() else [id],"equipped_item":id,"equipped_armor":""}
			if target=="guardian": guards.enemies[0]=24
			var before: int=guards.enemies[0] if target=="guardian" else live.state.health
			guards.cooldown=0
			if not check(guards.strike(),"Aimed strike missed "+target+" with "+id):return
			var after: int=guards.enemies[0] if target=="guardian" else live.state.health
			var expected:=4 if id.is_empty() else 8
			if not check(before-after==expected,"Wrong melee damage: %s %s expected%d got%d" % [target,id,expected,before-after]):return
			if not check(not guards.strike(),"Strike bypassed cooldown"):return
			print("PASS ",target," ",id," loss=",before-after)
	scene.queue_free()
	await process_frame
	print("PASS Hive weapon admission through actual aimed strikes: unarmed, captain, Stalagmite, Museum sword; both targets and cooldown")
	quit()
