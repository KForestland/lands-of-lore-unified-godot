extends "res://tests/l12_logs_approach_earned_test.gd"
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame
	e = InputEventKey.new()
	e.keycode = code
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame

func open_map(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	return scene

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l19_ghostly_heads_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned heads save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L19_BC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = await open_map("res://scenes/lol2/maps/L19_BC.tscn")
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned heads input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var dawn = scene.get_node("L19DawnCurse")
	var heads = scene.get_node("L19GhostlyHeads")
	if not check(heads.state().shot.size() == 4, "heads save still has four shots"):
		await stop(scene, 1); return
	scene.player.position = dawn.ACTOR_AT
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 0
	await process_frame
	await key(KEY_E)
	if not check(int(dawn.state().clicks) == 0, "actor 39 is not the click"):
		await stop(scene, 1); return
	scene.player.position = dawn.DAWN_AT
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	if not check(int(dawn.state().clicks) == 1 and not bool(dawn.state().curse_said), "the first E does not store the curse line"):
		await stop(scene, 1); return
	await key(KEY_E)
	if not check(int(dawn.state().clicks) == dawn.CURSE_AT and bool(dawn.state().curse_said) and str(dawn.state().line) == dawn.CURSE_LINE, "the second E records the curse sentence"):
		await stop(scene, 1); return
	await key(KEY_E)
	var offered: bool = int(dawn.state().clicks) == dawn.RUBY_AT and bool(dawn.state().ruby_offered) and not dawn.grants_ruby()
	if not check(offered, "the third E records the offer and does not grant the ruby"):
		await stop(scene, 1); return
	var l19_save := "res://tmp/l19_dawn_curse_earned_save.json"
	if not check(scene._quicksave_unrecorded(l19_save).is_empty(), "dawn save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(l19_save).is_empty(), "dawn reload"):
		await stop(scene, 1); return
	dawn = scene.get_node("L19DawnCurse")
	await process_frame
	if not check(int(dawn.state().clicks) == 3 and bool(dawn.state().curse_said), "L19 save keeps the curse line"):
		await stop(scene, 1); return
	var horn_id := "act2:L19_BC:horn"
	var had_horn: bool = horn_id in scene.carried_collected
	var kept_keys: Array = []
	for key in ["l19_dawn_curse", "l19_ghostly_heads", "l19_belial_horn", "l19_beast_wall", "l19_sewer_forms", "l19_drain_path"]:
		if scene.quest_state.has(key):
			kept_keys.append(key)
	var before_changes: int = scene.progression.level_changes.size()
	scene.progression.enter_region(2369)
	await process_frame
	var changes: Array = scene.progression.level_changes
	var requested: bool = changes.size() == before_changes + 1 and int(changes[-1].level) == 20 and int(changes[-1].selector) == 1
	if not check(requested, "region 2369 requests L20 arrival 1: %s" % [changes]):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = true
	scene.progression._change_level(changes[-1])
	await scene_changed
	scene = current_scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var arrived: bool = scene.ready_for_review and scene.area_id == "L20_BB" and int(scene.start_selector) == 1 and scene.arrived_by_level_change
	if not check(arrived, "L20 arrival 1 from the L19 handoff"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	var curse_now: Variant = scene.quest_state.get("l19_dawn_curse", {})
	var curse_kept: bool = curse_now is Dictionary and int(curse_now.get("clicks", -1)) == 3 and bool(curse_now.get("curse_said", false))
	if not check(curse_kept, "the handoff keeps the curse line"):
		await stop(scene, 1); return
	var keys_kept := true
	for key in kept_keys:
		if not scene.quest_state.has(str(key)):
			keys_kept = false
	if not check(keys_kept, "the handoff keeps the L19 quest keys"):
		await stop(scene, 1); return
	if had_horn and not check(horn_id in scene.carried_collected, "the handoff keeps the horn"):
		await stop(scene, 1); return
	var mother = scene.get_node("L20MotherCurse")
	scene.player.position = mother.MOTHER_AT
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 1
	mother.cast_level = 5
	await process_frame
	await key(KEY_E)
	if not check(not bool(mother.state().glob_entered), "Beast form does not cast"):
		await stop(scene, 1); return
	scene.player_form = 0
	mother.cast_level = 4
	await process_frame
	await key(KEY_E)
	if not check(not bool(mother.state().glob_entered) and not mother.accepts_level(4), "level 4 does not enter the mother"):
		await stop(scene, 1); return
	var before: Vector3 = scene.player.position
	mother.cast_level = 5
	await process_frame
	await key(KEY_E)
	var cast: bool = bool(mother.state().glob_entered) and mother.ANCIENT_LEVEL == 5 and not mother.plays_movie() and mother.DEMONS == -1 and mother.DOOR == -1 and not bool(mother.state().demons_killed) and not mother.relocates_player() and scene.player.position.distance_to(before) < 0.1
	if not check(cast, "level 5 records the glob and Luther stays"):
		await stop(scene, 1); return
	var save := "res://tmp/l20_dawn_curse_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "mother save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "mother reload"):
		await stop(scene, 1); return
	mother = scene.get_node("L20MotherCurse")
	await process_frame
	if not check(bool(mother.state().glob_entered) and bool(mother.state().curse_said) and not bool(mother.state().demons_killed), "L20 save keeps the cast"):
		await stop(scene, 1); return
	print("PASS earned Dawn clicks and the level-5 curse")
	await stop(scene, 0)
