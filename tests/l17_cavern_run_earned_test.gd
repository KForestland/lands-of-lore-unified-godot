extends "res://tests/l12_logs_approach_earned_test.gd"
const WALK := [[-5770.5, 5826.6], [-5632.0, 5803.5], [-5436.0, 5802.0]]
const ARRIVAL := Vector3(1434, 32, -7075)
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_dragon_room_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned dragon save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned dragon input"):
		await stop(scene, 1); return
	prepare(scene)
	scene.progression.change_scene_enabled = false
	var room = scene.get_node("L16DragonRoom")
	var dragon: Variant = scene.quest_state.get("l16_dragon_room", {})
	var chopped: bool = dragon is Dictionary and bool(dragon.get("chopped", false)) and bool(dragon.get("pad_seen", false))
	if not check(chopped and room.DEST_LEVEL == 17 and room.DEST_SELECTOR == 1, "dragon save keeps the chop and the pad"):
		await stop(scene, 1); return
	var before: int = scene.progression.level_changes.size()
	var fired: Array = scene.progression.use_exit("control:74")
	for i in 10:
		await process_frame
	var changes: Array = scene.progression.level_changes
	var requested: bool = changes.size() > before and int(changes[-1].level) == 17 and int(changes[-1].selector) == 1
	if not check(requested, "control 74 requests L17 arrival 1: %s %s" % [fired, changes]):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = true
	scene.progression._change_level(changes[-1])
	await scene_changed
	scene = current_scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	prepare(scene)
	scene.progression.change_scene_enabled = false
	var arrived: bool = scene.area_id == "L17_HC" and int(scene.start_selector) == 1 and scene.arrived_by_level_change
	arrived = arrived and scene.player.position.distance_to(ARRIVAL) < 2.0
	if not check(arrived, "L17 arrival 1 at (1434, 32, -7075): %s" % scene.player.position):
		await stop(scene, 1); return
	var kept: Variant = scene.quest_state.get("l16_dragon_room", {})
	if not check(kept is Dictionary and bool(kept.get("chopped", false)), "the chop survives the handoff"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-5732, 32, 5829)
	scene.player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	var run = scene.get_node("L17CavernRun")
	var ids_ok: bool = run.FORWARD_REGIONS == [1312, 1313] and run.FORWARD_LEVEL == 19 and not run.KILL_REQUIRED
	if not check(ids_ok, "cavern exit ids"):
		await stop(scene, 1); return
	if not await walk(scene, WALK, "placed walk to region 1312"):
		await stop(scene, 1); return
	await process_frame
	var reached: bool = int(run.state().exit_region) == 1312 and scene.area_id == "L17_HC" and not run.relocates_player()
	if not check(reached, "region 1312 records and the scene stays on L17"):
		await stop(scene, 1); return
	var save := "res://tmp/l17_cavern_run_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "cavern save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "cavern reload"):
		await stop(scene, 1); return
	run = scene.get_node("L17CavernRun")
	await process_frame
	if not check(int(run.state().exit_region) == 1312, "save keeps region 1312"):
		await stop(scene, 1); return
	print("PASS earned dragon save -> control 74 -> L17 arrival 1 -> region 1312")
	await stop(scene, 0)
