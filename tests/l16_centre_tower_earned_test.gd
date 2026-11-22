extends "res://tests/l12_logs_approach_earned_test.gd"
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	e = InputEventKey.new(); e.keycode = code; e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame

func _mantle_posed(scene: Node, id: int) -> bool:
	var row: Variant = scene.prop_placements.get(id)
	if not row is Array: return false
	var entry: Array = row
	var at: Vector3 = entry[2]
	var multi: MultiMesh = entry[0]
	var origin: Vector3 = multi.get_instance_transform(int(entry[1])).origin
	var dest: Vector3 = preload("res://scripts/lol2/l16_centre_tower.gd").pose_for(id)
	return absf(origin.x - dest.x) < 1.0 and absf(origin.z - dest.z) < 1.0 and origin.y > at.y + 20.0

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_sw_chips_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned SW pedestal save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned SW pedestal input"):
		await stop(scene, 1); return
	prepare(scene)
	var hall = scene.get_node("L16CentreTower")
	var ne = scene.get_node("L16NeTower")
	var chips = scene.get_node("L16SwChips")
	var ids_ok: bool = hall.DOOR_ID == -1 and hall.ACTOR == 45 and ne.SECTIONS == 0 and chips.PYRAMID == 604
	if not check(ids_ok, "centre ids and S sections"):
		await stop(scene, 1); return
	var ne_state: Variant = scene.quest_state.get("l16_ne_tower", {})
	var sw_state: Variant = scene.quest_state.get("l16_sw_chips", {})
	var placed: Variant = sw_state.get("placed", []) if sw_state is Dictionary else []
	var carried: bool = ne_state is Dictionary and bool(ne_state.get("at_doors", false))
	carried = carried and placed is Array and (placed as Array).is_empty()
	if not check(carried, "SW save keeps the NE door and empty pedestals"):
		await stop(scene, 1); return
	scene.player.position = Vector3(2292, 32, -2950)
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var door_ok: bool = bool(ne.state().at_doors) and chips.state().placed.is_empty()
	if not check(door_ok, "S01 door quad and empty S04 pedestals"):
		await stop(scene, 1); return
	scene.player.position = Vector3(5460, 32, 9760)
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var at_bars: bool = bool(hall.state().at_bars) and not hall.relocates_player()
	if not check(at_bars, "mantle hall records the bars: '%s'" % hall.hint.text):
		await stop(scene, 1); return
	var stayed: bool = scene.player.position.distance_to(Vector3(5460, 32, 9760)) < 1.0 and ne.SECTIONS == 0
	if not check(stayed, "Luther stays and the centre count stays 0"):
		await stop(scene, 1); return
	scene.player.position = hall.BARS
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	await process_frame
	var posed: bool = bool(hall.state().conveyed) and _mantle_posed(scene, 331) and int(scene.progression.native.get("locals").get(12, -1)) == 1
	posed = posed and scene.player.position.distance_to(hall.BARS) < 5.0 and not hall.relocates_player() and hall.DOOR_ID == -1
	if not check(posed, "region 218 poses the mantle props and Luther stays at %s" % scene.player.position):
		await stop(scene, 1); return
	scene.player.position = hall.ACTOR_AT
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var seen: bool = bool(hall.state().seen_actor) and hall.fight_hosted() and hall.get_node("FoeBody").visible
	if not check(seen, "actor 45 is seen and the foe is standing"):
		await stop(scene, 1); return
	var foe_before: Vector3 = scene.player.position
	if str(scene.equipped_item) == "":
		scene.equipped_item = "act2:L16_CA:item24" if "act2:L16_CA:item24" in scene.carried_collected else "act2:L12_CM:blue_bow"
	scene.player_form = 0
	await process_frame
	await key(KEY_E)
	var fell: bool = bool(hall.state().foe_down) and not hall.get_node("FoeBody").visible and scene.player.position.distance_to(foe_before) < 1.0 and not hall.relocates_player() and _mantle_posed(scene, 331)
	if not check(fell, "actor 45 falls, the mantle props stay posed, and Luther stays"):
		await stop(scene, 1); return
	for record in [331, 615]:
		var row: Variant = scene.prop_placements.get(record)
		if not check(row is Array, "prop %d placement" % record):
			await stop(scene, 1); return
		var standing: bool = (row[0] as MultiMesh).get_instance_transform(int(row[1])).basis.get_scale().length() > 0.5
		if not check(standing, "prop %d stays up" % record):
			await stop(scene, 1); return
	var save := "res://tmp/l16_centre_tower_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "centre save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "centre reload"):
		await stop(scene, 1); return
	hall = scene.get_node("L16CentreTower")
	await process_frame
	var kept: bool = bool(hall.state().at_bars) and bool(hall.state().seen_actor) and bool(hall.state().foe_down) and bool(hall.state().conveyed) and hall.DOOR_ID == -1 and not hall.get_node("FoeBody").visible and _mantle_posed(scene, 331)
	if not check(kept, "save keeps the hall record and the posed props"):
		await stop(scene, 1); return
	print("PASS earned SW pedestal save -> region 218 poses the mantle props, actor 45 falls, Luther stays")
	await stop(scene, 0)
