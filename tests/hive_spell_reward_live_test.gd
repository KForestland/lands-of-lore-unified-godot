extends "res://tests/player_magic_handoff_test.gd"
const Reward = preload("res://scripts/lol2/hive_live_spell_reward.gd")
func total(player: Dictionary) -> int:
	var result := int(player.experience)
	var table = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_reward_thresholds.json")).thresholds
	for level in range(1,int(player.level)): result += int(table[level])
	return result
func run() -> void:
	var initial := Magic.initial()
	assert(Reward.apply(initial,123,1).award == 30)
	assert(Reward.apply(initial,123,8).award == 90)
	assert(Reward.apply(initial,123,0).award == 0)
	assert(Reward.apply(initial,123,-1).has("error"))
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	scene.set_physics_process(false)
	scene.starting_magic.set_process(false)
	scene.get_node("Warriors").set_process(false)
	scene.get_node("Nest").set_physics_process(false)
	scene.get_node("Nest").chasm_handoff()
	var live = scene.executioner_live
	live.set_physics_process(false)
	live.advance(0.01)
	scene.player.position = live.SPAWN+Vector3(0,32,65)
	scene.camera.look_at(live.body.global_position)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await physics_frame
	var fighting: Dictionary = scene.player_reward_checkpoint.duplicate(true)
	var spells = scene.starting_magic
	spells.select_spell("spark")
	assert(spells.cast())
	assert(live.state.health == 292 and scene.player_magic_checkpoint.player.experience == 90)
	assert(scene.player_magic_checkpoint.player.mana == 19 and scene.player_magic_checkpoint.cooldown == 0.5)
	assert(scene.player_reward_checkpoint == fighting)
	var path := "user://tests/executioner_spell_reward.json"
	assert(scene.quicksave(path).is_empty())
	var snapshot: Dictionary = scene.player_magic_checkpoint.duplicate(true)
	var health := int(live.state.health)
	spells._process(0.5)
	assert(spells.cast() and scene.player_magic_checkpoint.player.experience == 180)
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(scene.player_magic_checkpoint == snapshot and live.state.health == health)
	# Aiming away spends mana but grants no cast-time or hit experience.
	spells._process(0.5)
	scene.camera.rotation = Vector3(-PI/2,0,0)
	assert(spells.cast() and scene.player_magic_checkpoint.player.experience == 90)
	scene.camera.look_at(live.body.global_position)
	# Defeat through actual aimed casts, including source magic level growth.
	for i in 50:
		if live.state.health == 0: break
		spells._process(0.5)
		var before: Dictionary = scene.player_magic_checkpoint.duplicate(true)
		var predicted := Reward.apply(before,int(live.state.get("reward_seed",324508639)),8)
		var xp := total(before.player)
		assert(spells.cast())
		assert(total(scene.player_magic_checkpoint.player) == xp+int(predicted.award))
		assert(scene.player_reward_checkpoint == fighting)
		await process_frame
	assert(live.state.health == 0 and live.state.mode == "dying")
	assert(scene.player_magic_checkpoint.player.level > 1)
	var final: Dictionary = scene.player_magic_checkpoint.duplicate(true)
	assert(not live.receive_strike(8,false,20) and scene.player_magic_checkpoint == final)
	assert(scene.quicksave(path).is_empty())
	assert(scene.quickload(path).is_empty() and scene.player_magic_checkpoint == final)
	var handoff: Dictionary = scene.area_handoff()
	await finish(scene)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene = jungle
	await process_frame
	jungle.set_physics_process(false)
	jungle.starting_magic.set_process(false)
	assert(jungle.apply_area_handoff(handoff).is_empty())
	assert(jungle.starting_magic.magic_state() == final)
	assert(jungle.quicksave(path).is_empty())
	assert(jungle.quickload(path).is_empty() and jungle.starting_magic.magic_state() == final)
	await finish(jungle)
	print("PASS actual Spark ray hits award magic only, debit/cooldown retained, miss/corpse grant nothing, level growth, kill without melee multiplier and disk rollback")
	quit()
