extends SceneTree
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	var guards=scene.get_node("Warriors")
	guards.set_process(false)
	var spells=scene.starting_magic
	spells.set_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	guards.health=10
	key(KEY_2)
	key(KEY_Q)
	if not check(guards.health==16 and spells.magic_state().player.mana==18,"Healing effect/debit failed"): return
	if not check(not spells.cast() and guards.health==16,"Cooldown allowed duplicate heal"): return
	var reward: Dictionary=preload("res://scripts/lol2/hive_magic_reward.gd").award_checkpoint(spells.magic_state(),1,[0,0,0])
	if not check(not reward.has("error") and reward.checkpoint.spell=="heal" and reward.checkpoint.cooldown==0.5,"Magic XP lost selection/cooldown"): return
	var path:="user://tests/starting_magic.json"
	if not check(scene.quicksave(path).is_empty(),"Spell save failed"): return
	spells._process(0.5)
	scene.player_form=1
	if not check(not spells.cast() and spells.magic_state().player.mana==18,"Beast cast Healing"): return
	scene.player_form=2
	if not check(spells.cast() and guards.health==22,"Lizard could not heal"): return
	if not check(scene.quickload(path).is_empty() and guards.health==16 and spells.magic_state().player.mana==18 and spells.magic_state().spell=="heal" and not spells.cast(),"Loaded cast replayed/reset cooldown or mana"): return
	scene.set_physics_process(false)
	spells._process(0.5)
	spells.select_spell("spark")
	scene.player.position=guards.POSITIONS[0]+Vector3(0,32,65)
	scene.camera.look_at(guards.POSITIONS[0]+Vector3(0,35,0))
	for i in range(3): await physics_frame
	if not check(spells.cast() and guards.enemies[0]==16 and spells.magic_state().player.mana==17,"Spark failed aimed guardian hit"): return
	spells._process(0.5)
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(80,100,4)
	shape.shape=box;wall.add_child(shape)
	wall.position=guards.POSITIONS[0]+Vector3(0,35,30)
	root.add_child(wall)
	for i in range(2): await physics_frame
	if not check(spells.cast() and guards.enemies[0]==16 and spells.magic_state().player.mana==16,"Spark passed through wall or miss did not cost mana"): return
	wall.queue_free()
	spells._process(0.5)
	scene.interface_hud.set_cursor(true)
	if not check(not spells.cast(),"Overlay allowed casting"): return
	spells._process(30)
	if not check(spells.magic_state().player.mana==16,"Modal overlay advanced mana regeneration"): return
	scene.interface_hud.set_cursor(false)
	spells._process(6)
	if not check(spells.magic_state().player.mana==18,"Playable mana regeneration failed"): return
	var before: Dictionary=scene.area_handoff()
	var bad: Dictionary=before.duplicate(true)
	bad.quests.player_magic_reward_state.spell="all_spells"
	if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Invalid selection mutated state"): return
	spells._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/starting_magic.png")
	for i in range(15): await process_frame
	scene.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(path)
	print("PASS: Healing, Spark combat/occlusion/miss cost, cooldown, Beast/Lizard, modal block, spell/mana/cooldown disk rollback and invalid atomicity")
	quit()
