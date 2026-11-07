extends "res://tests/l12_logs_approach_earned_test.gd"
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
	scene.player.position = hall.ACTOR_AT
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var seen: bool = bool(hall.state().seen_actor) and not hall.fight_hosted()
	if not check(seen, "actor 45 is seen and the fight stays off"):
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
	var kept: bool = bool(hall.state().at_bars) and bool(hall.state().seen_actor) and hall.DOOR_ID == -1
	if not check(kept, "save keeps the hall record"):
		await stop(scene, 1); return
	print("PASS earned SW pedestal save -> empty pedestals, then the mantle hall")
	await stop(scene, 0)
