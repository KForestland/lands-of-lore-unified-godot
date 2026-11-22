extends "res://tests/l12_logs_approach_earned_test.gd"
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

const CAB_STAND := Vector3(2621, -68, -840)
const DOOR_STAND := Vector3(2550, -68, -830)
const DOOR_AIM := Vector3(2550, -100, -854)
const CAB_PLATFORM := 1943
const CAB_RING := 1935

func key(code: Key, ctrl:=false, shift:=false) -> void:
	var e := InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.ctrl_pressed = ctrl; e.shift_pressed = shift
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame
	e = InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.ctrl_pressed = ctrl; e.shift_pressed = shift
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame

func look_at_point(scene: Node, at: Vector3) -> void:
	scene.camera.global_position = scene.player.global_position + Vector3(0, 10, 0)
	scene.camera.look_at(at, Vector3.UP)

func stand_at(scene: Node, at: Vector3, label: String) -> void:
	print("TELEPORT ", label)
	scene.player.position = at
	scene.player.velocity = Vector3.ZERO
	for _i in 3:
		await physics_frame

func cab_bottom(scene: Node) -> bool:
	var pr: Node = scene.progression
	await stand_at(scene, DOOR_STAND, "cab door")
	look_at_point(scene, DOOR_AIM)
	await key(KEY_E)
	if not check(int(pr.native.locals.get(4, -1)) == 0, "the cab door writes local 4 as 0"):
		return false
	# The heads save is a settled fixture: the cab rests at the bottom (-1000). The door's call brings it up; wait for it,
	# as a player waits at the door (lead 2026-11-14).
	for _up in 400:
		if int(pr.regions[CAB_PLATFORM][1]) == -100 and int((pr.floor_motion.get(CAB_PLATFORM, {"remaining": 0}) as Dictionary).remaining) == 0: break
		pr.advance_floors(8.0 / 60.0)
		await process_frame
	if not check(int(pr.regions[CAB_PLATFORM][1]) == -100, "the cab comes up to the door (floor %d)" % int(pr.regions[CAB_PLATFORM][1])):
		return false
	await stand_at(scene, CAB_STAND, "cab stand")
	if not check(int(pr.native.locals.get(4, -1)) == 1, "stepping onto the cab runs the down group"):
		return false
	var arrived := false
	for _step in 160:
		pr.advance_floors(8.0 / 60.0)
		await process_frame
		if int(pr.regions[CAB_PLATFORM][1]) == -1000 and int(pr.regions[CAB_RING][1]) == -990:
			arrived = true
			break
	var bottom_y: float = scene.player.position.y
	if not check(arrived and bottom_y < -900.0, "the cab reaches the bottom (y %s)" % bottom_y):
		return false
	var save := "res://tmp/l19_cab_bottom_earned_save.json"
	var saved: String = scene._quicksave_unrecorded(save)
	if not check(saved.is_empty(), "cab bottom save %s" % saved):
		return false
	var loaded: String = scene._quickload_unrecorded(save)
	if not check(loaded.is_empty(), "cab bottom reload %s" % loaded):
		return false
	pr = scene.progression
	var kept: bool = int(pr.regions[CAB_PLATFORM][1]) == -1000 and int(pr.regions[CAB_RING][1]) == -990 and absf(scene.player.position.y - bottom_y) < 2.0
	return check(kept, "the reload keeps Luther on the cab bottom")

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
	if not check(dawn.get_node_or_null("MotherBody") == null and dawn.get_node_or_null("DemonWave") == null and dawn.get_node_or_null("BirthDoor") == null, "L19 does not build the mother boxes"):
		await stop(scene, 1); return
	if not check(heads.state().shot.size() == 4, "heads save still has four shots"):
		await stop(scene, 1); return
	if not await cab_bottom(scene):
		await stop(scene, 1); return
	dawn = scene.get_node("L19DawnCurse")
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
	var offered: bool = int(dawn.state().clicks) == dawn.RUBY_AT and bool(dawn.state().ruby_offered) and dawn.grants_ruby() and dawn.RUBY_ID in scene.carried_collected
	if not check(offered, "the third E grants the Ruby of Truth"):
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
	# Adapter L19_to_L20_history (lead 2026-11-14, DEVIATIONS 0661): the door takes the unknown cell 52 from the player's
	# own L20 history - the curse is not yet cast into the mother here, so 0 and predicate 204 chooses arrival 1.
	scene.progression.enter_region(2369)
	await process_frame
	if not check(int(scene.progression.native.locals_e58.get(52, -1)) == 0, "the door takes cell 52 from the L20 history (0)"):
		await stop(scene, 1); return
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
	if not check("act2:L19_BC:ruby_of_truth" in scene.carried_collected, "the handoff keeps the ruby"):
		await stop(scene, 1); return
	var mother = scene.get_node("L20MotherCurse")
	var alive_before: int = 0
	for id in scene.act2_creatures.state.actors:
		if bool(scene.act2_creatures.state.actors[id].present):
			alive_before += 1
	if not check(alive_before > 0, "L20 has creatures before the birth"):
		await stop(scene, 1); return
	scene.player_form = 0
	var physics: bool = scene.is_physics_processing()
	scene.set_physics_process(false)
	var approaches: Array[Vector3] = [Vector3(0, 8, 80), Vector3(0, 8, -80), Vector3(-80, 8, 0), Vector3(80, 8, 0)]
	for start in approaches:
		scene.player.position = mother.MOTHER_AT + start
		scene.player.velocity = Vector3.ZERO
		var stuck: int = 0
		var previous: Vector3 = scene.player.position
		for _tick in 400:
			if mother.flat_to(mother.MOTHER_AT) < mother.REACH - 2.0:
				break
			var step_to: Vector3 = mother.MOTHER_AT - scene.player.position
			step_to.y = 0.0
			if step_to.length() < 0.01:
				break
			scene.move_grounded(step_to.normalized(), 1.0 / 60.0)
			await physics_frame
			var moved: float = Vector2(scene.player.position.x - previous.x, scene.player.position.z - previous.z).length()
			previous = scene.player.position
			stuck = stuck + 1 if moved < 0.05 else 0
			if stuck >= 25:
				break
		if mother.flat_to(mother.MOTHER_AT) < mother.REACH:
			break
	scene.set_physics_process(physics)
	if not check(mother.flat_to(mother.MOTHER_AT) < mother.REACH, "walked to the mother at %s" % scene.player.position):
		await stop(scene, 1); return
	# Explicit teaching fixture for this old checkpoint, not new acquisition proof.
	check(scene.starting_magic.learn_spell_group("control"), "Legacy Expel teaching fixture")
	await key(KEY_3)
	scene.player_form = 1
	mother.cast_level = 5
	await process_frame
	await key(KEY_Q,false,true)
	if not check(not bool(mother.state().glob_entered), "Beast form does not cast"):
		await stop(scene, 1); return
	scene.player_form = 0
	mother.cast_level = 4
	await process_frame
	await key(KEY_Q,false,true)
	if not check(not bool(mother.state().glob_entered) and not mother.accepts_level(4), "level 4 does not enter the mother"):
		await stop(scene, 1); return
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	var before: Vector3 = scene.player.position
	mother.cast_level = 5
	await process_frame
	await key(KEY_Q,false,true)
	mother.skip_birth()
	await process_frame
	var card: Label = mother.find_child("Stage", true, false) as Label
	var yaw: float = -TAU * float(mother.BIRTH_HEADING) / 65536.0
	var cast: bool = bool(mother.state().glob_entered) and mother.ANCIENT_LEVEL == 5 and mother.plays_movie() and not mother.IN_MOVIE_TABLE and mother.DEMONS == -1 and mother.DOOR == -1 and not bool(mother.state().demons_killed) and not mother.relocates_player()
	cast = cast and absf(scene.player.position.x - float(mother.BIRTH_X)) < 0.1 and absf(scene.player.position.z + float(mother.BIRTH_Y)) < 0.1 and absf(scene.player.position.y - before.y) < 0.1
	cast = cast and absf(angle_difference(scene.player.rotation.y, yaw)) < 0.001 and mother.birth_plays == 1 and not mother.birth_reel_started
	cast = cast and card != null and "Belial's birth" in card.text and mother.get_node("MotherBody").visible
	if not check(cast, "level 5 runs group 770 and the consumer stands at the birth words (%s)" % scene.player.position):
		await stop(scene, 1); return
	var stayed: Vector3 = scene.player.position
	await key(KEY_E)
	var door: MeshInstance3D = mother.get_node("BirthDoor") as MeshInstance3D
	var killed: bool = bool(mother.state().demons_killed) and not bool(mother.state().mother_dead) and not mother.PLAYER_KILLS_MOTHER and not mother.get_node("DemonWave").visible and mother.get_node("MotherBody").visible and door.position.y > mother.MOTHER_AT.y + 1.0 and scene.player.position.distance_to(stayed) < 0.1
	if not check(killed, "the demons fall, the mother is still standing, and the birth door opens"):
		await stop(scene, 1); return
	for _frame in 180:
		if bool(mother.state().mother_dead):
			break
		await process_frame
	var quiet: bool = bool(mother.state().mother_dead) and bool(mother.state().creatures_cleared) and not mother.get_node("MotherBody").visible
	var still_here: int = 0
	for id in scene.act2_creatures.state.actors:
		if bool(scene.act2_creatures.state.actors[id].present):
			still_here += 1
	if not check(quiet and still_here == 0, "she dies after the birth and the creatures are gone, still %s" % still_here):
		await stop(scene, 1); return
	var Live = preload("res://scripts/lol2/creature_live_rules.gd")
	var Population = preload("res://scripts/lol2/scripted_creature_state.gd")
	var pursued: Dictionary = scene.act2_creatures.state.live["35"]
	pursued.mode = Live.PURSUE
	pursued.elapsed = 0.0
	pursued.hit = false
	var birth_packet: String = Population.validate(scene.act2_creatures.state, scene.act2_creatures.src)
	if not check(not bool(scene.act2_creatures.state.actors["35"].present) and birth_packet.is_empty(), "the cleared demon stays in pursue and the save packet is accepted (%s)" % birth_packet):
		await stop(scene, 1); return
	var save := "res://tmp/l20_dawn_curse_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "mother save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "mother reload"):
		await stop(scene, 1); return
	mother = scene.get_node("L20MotherCurse")
	await process_frame
	still_here = 0
	for id in scene.act2_creatures.state.actors:
		if bool(scene.act2_creatures.state.actors[id].present):
			still_here += 1
	var kept_pursue: bool = int(scene.act2_creatures.state.live["35"].mode) == Live.PURSUE and not bool(scene.act2_creatures.state.actors["35"].present)
	if not check(bool(mother.state().mother_dead) and bool(mother.state().creatures_cleared) and not mother.get_node("MotherBody").visible and still_here == 0 and kept_pursue, "L20 save keeps the death, the empty area, and the cleared demon's pursue mode"):
		await stop(scene, 1); return
	print("PASS earned Dawn's ruby, the birth, and the mother's death: the player did not kill her, and the area's creatures are gone")
	await stop(scene, 0)
