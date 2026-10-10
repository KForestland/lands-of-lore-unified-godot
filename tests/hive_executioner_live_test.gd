extends SceneTree
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_physics_process(false)
	var live=scene.executioner_live
	live.set_physics_process(false)
	var guards=scene.get_node("Warriors")
	guards.set_process(false)
	var nest=scene.get_node("Nest")
	nest.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if not check(not live.active() and live.body.collision_layer==0,"Dormant Executioner collides"): return
	nest.chasm_handoff()
	live.advance(0.01)
	scene.player.position=live.SPAWN+Vector3(0,32,160)
	var start: Vector3=live.body.position
	for i in range(30):
		await physics_frame
		live.advance(1.0/60.0)
	if not check(live.body.position.distance_to(start)>5,"Executioner did not pursue visible player"): return
	var paused_state: Dictionary=live.checkpoint()
	scene.interface_hud.set_cursor(true)
	live.advance(1.0)
	if not check(live.checkpoint()==paused_state,"Interface did not suspend Executioner"): return
	scene.interface_hud.set_cursor(false)
	live.restore(live.initial())
	scene.player.position=live.SPAWN+Vector3(0,32,65)
	scene.camera.look_at(live.body.global_position)
	for i in range(3): await physics_frame
	if not check(live.in_reach(),"Source actor/player attack fixture is obstructed"): return
	live.advance(0.01)
	live.advance(0.4)
	if not check(live.state.mode=="attack" and guards.health==30,"Windup damaged early"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/executioner_live.png")
	var path := "user://tests/executioner_live_test.json"
	if not check(scene.quicksave(path).is_empty(),"Partial attack save failed"): return
	live.advance(0.2)
	if not check(guards.health==24 and live.state.hit_sent,"Source hit frame did not damage"): return
	live.advance(0.1)
	if not check(guards.health==24,"Attack applied twice"): return
	if not check(scene.quickload(path).is_empty(),"Partial attack load failed"): return
	scene.set_physics_process(false)
	live.advance(0.2)
	if not check(guards.health==24,"Resumed attack did not reproduce damage"): return
	var saved: Dictionary=live.checkpoint()
	var invalid: Dictionary=scene.area_handoff()
	invalid.quests.hive_executioner_live.health=-1
	if not check(not scene.apply_area_handoff(invalid).is_empty() and live.checkpoint()==saved,"Invalid handoff mutated actor"): return
	# Blocking collision between actor/player cancels damage at the hit frame.
	if not check(scene.quickload(path).is_empty(),"Attack rollback failed"): return
	scene.set_physics_process(false)
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(100,100,4)
	shape.shape=box;wall.add_child(shape)
	wall.position=live.SPAWN+Vector3(0,35,30)
	root.add_child(wall)
	for i in range(2): await physics_frame
	live.advance(0.2)
	if not check(guards.health==30,"Executioner hit through wall"): return
	wall.queue_free()
	await physics_frame
	# Player strikes use the same aimed collider and cooldown as guardians.
	scene.carried_inventory={"collected":[scene.Save.Shared.Museum.SWORD],"equipped_item":scene.Save.Shared.Museum.SWORD,"equipped_armor":""}
	scene.camera.look_at(live.body.global_position)
	guards.cooldown=0
	if not check(guards.strike() and live.state.health==292,"Aimed sword did not hit Executioner"): return
	if not check(scene.player_reward_checkpoint.player.experience==20,"Source scale8/level1 hit did not award20 experience"): return
	if not check(not guards.strike() and live.state.health==292,"Player cooldown bypass"): return
	if not check(scene.player_reward_checkpoint.player.experience==20,"Rejected strike awarded experience"): return
	for i in range(37):
		guards.cooldown=0
		if not check(guards.strike(),"Aimed lethal sequence missed"): return
	if not check(live.state.health==0 and live.state.mode=="dying" and live.body.collision_layer==0 and nest.actor.visible,"Defeated Executioner remains active"): return
	var earned: Dictionary = scene.player_reward_checkpoint.duplicate(true)
	if not check(earned.player.level>1,"Executioner melee awards never crossed a level threshold"): return
	if not check(not live.receive_strike(8) and scene.player_reward_checkpoint==earned,"Corpse awarded duplicate experience"): return
	live.advance(0.2)
	if not check(scene.quicksave(path).is_empty(),"Partial death save failed"): return
	live.advance(0.5)
	if not check(live.state.mode=="dead" and nest.actor.visible,"Corpse did not follow death animation"): return
	if not check(scene.quickload(path).is_empty() and live.state.mode=="dying" and is_equal_approx(live.state.elapsed,0.2),"Death animation rollback failed"): return
	scene.set_physics_process(false)
	live.advance(0.5)
	if not check(live.state.mode=="dead" and live.body.collision_layer==0,"Resumed death did not finish"): return
	await RenderingServer.frame_post_draw
	scene.camera.look_at(nest.actor.global_position+Vector3(0,15,0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/executioner_corpse.png")
	if not check(scene.quicksave(path).is_empty(),"Defeat save failed"): return
	live.restore(live.initial())
	if not check(scene.quickload(path).is_empty() and live.state.health==0,"Defeat did not survive load"): return
	if not check(scene.player_reward_checkpoint==earned,"Earned combat progression did not survive load"): return
	var transfer: Dictionary=scene.area_handoff()
	if not check(scene.Save.Shared.Quests.validate(JSON.parse_string(JSON.stringify(transfer.quests))).is_empty(),"Travel checkpoint invalid"): return
	DirAccess.remove_absolute(path)
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: live Executioner activation, aimed hits/cooldown, source hit frame, occlusion, partial save replay, invalid rollback, defeat and travel persistence")
	quit()
