extends "res://tests/l12_logs_approach_earned_test.gd"
const WALK := [[-5770.5, 5826.6], [-5632.0, 5803.5], [-5436.0, 5802.0]]
const ARRIVAL := Vector3(84, 22, 305)
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l17_beast_blade_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned blade save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L17_HC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L17_HC.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned blade input"):
		await stop(scene, 1); return
	prepare(scene)
	scene.progression.change_scene_enabled = false
	var run = scene.get_node("L17CavernRun")
	var blade = scene.get_node("L17BeastBlade")
	var cut: bool = bool(blade.state().cut) and int(run.state().exit_region) == 1312
	if not check(cut, "blade save keeps the cut and region 1312"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-5732, 32, 5829)
	scene.player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	var before: int = scene.progression.level_changes.size()
	if not await walk(scene, WALK, "re-enter region 1312"):
		await stop(scene, 1); return
	for i in 10:
		await process_frame
	var changes: Array = scene.progression.level_changes
	var requested: bool = changes.size() > before and int(changes[-1].level) == 19 and int(changes[-1].selector) == 1
	if not check(requested, "region 1312 requests L19 arrival 1: %s" % [changes]):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = true
	scene.progression._change_level(changes[-1])
	await scene_changed
	scene = current_scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	prepare(scene)
	var wall = scene.get_node("L19BeastWall")
	var pose: bool = scene.area_id == "L19_BC" and int(scene.start_selector) == 1 and scene.arrived_by_level_change
	pose = pose and scene.player.position.distance_to(ARRIVAL) < 2.0
	if not check(pose, "L19 arrival 1 at (84, 22, 305): %s" % scene.player.position):
		await stop(scene, 1); return
	var carried: Variant = scene.quest_state.get("l17_cavern_run", {})
	if not check(carried is Dictionary and int(carried.get("exit_region", -1)) == 1312, "region 1312 survives the handoff"):
		await stop(scene, 1); return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before_pos: Vector3 = scene.player.position
	await process_frame
	await process_frame
	var gap: bool = wall.STRAND_ID == -1 and wall.MOVIE == -1 and wall.ARRIVAL_SELECTOR == -1
	if not check(gap, "strand, movie, and beast arrival stay unbound"):
		await stop(scene, 1); return
	var still: bool = bool(wall.state().noted) and not wall.plays_movie() and scene.player.position.distance_to(before_pos) < 1.0
	if not check(still, "the gap is noted and Luther stays: '%s'" % wall.hint.text):
		await stop(scene, 1); return
	if not check(scene.get_node_or_null("BeastMovie") == null, "no beast movie node"):
		await stop(scene, 1); return
	var save := "res://tmp/l19_beast_wall_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "beast wall save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "beast wall reload"):
		await stop(scene, 1); return
	wall = scene.get_node("L19BeastWall")
	await process_frame
	if not check(bool(wall.state().noted) and wall.MOVIE == -1, "save keeps the gap"):
		await stop(scene, 1); return
	print("PASS earned blade save -> region 1312 -> L19 arrival 1, beast arrival stays unbound")
	await stop(scene, 0)
