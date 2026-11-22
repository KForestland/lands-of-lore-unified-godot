extends "res://tests/l12_logs_approach_earned_test.gd"
const POCKET := Vector3(-6212.0, 32.0, 6264.25)
const LAND := Vector3(-6064.5, 32.0, 5904.0)
const SLIVER := Vector3(-6077.75, 32.0, 5992.0)
const READER := Vector3(-6084.0, 32.0, 6404.0)
const FORWARD := Vector3(-5436.0, 32.0, 5802.0)
const WALK: Array = [[-6055.0, 5828.0], [-6023.0, 5796.0], [-5959.0, 5796.0], [-5906.04, 5804.06], [-5632.0, 5803.5], [-5436.0, 5802.0]]
const BLADE := "act2:L13_RC:dark_sword"

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func region_of(scene: Node) -> int:
	return int(scene.progression.region_at(scene.player.global_position))

func run():
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l17_cavern_run_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned cavern save"):
		quit(1)
		return
	var input: Dictionary = Save.read_save(path, "lol2-restoration-map-L17_HC")
	if not check(str(input.error).is_empty(), str(input.error)):
		quit(1)
		return
	var scene: Node = load("res://scenes/lol2/maps/L17_HC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	var loaded: bool = scene.ready_for_review and str(scene.apply_save(input.state)).is_empty()
	if not check(loaded, "earned cavern input"):
		await stop(scene, 1)
		return
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var carry: Node = scene.get_node("L17BeastCarry")
	var run: Node = scene.get_node("L17CavernRun")
	var blade: Node = scene.get_node("L17BeastBlade")
	scene.player.position = POCKET
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 0
	scene.equipped_item = ""
	await process_frame
	var pocket_yaw: float = scene.player.rotation.y
	await key(KEY_E)
	if not check(not bool(carry.state().carried) and flat(scene.player.position, POCKET) < 1.0, "an empty hand does not cut"):
		await stop(scene, 1)
		return
	scene.player_form = 2
	scene.equipped_item = BLADE
	await key(KEY_E)
	if not check(not bool(carry.state().carried) and flat(scene.player.position, POCKET) < 1.0, "Lizard form does not cut"):
		await stop(scene, 1)
		return
	scene.player_form = 0
	scene.equipped_item = BLADE
	await key(KEY_E)
	var here: int = region_of(scene)
	var dist: float = flat(scene.player.global_position, LAND)
	var yaw_now: float = scene.player.rotation.y
	var same_yaw: bool = absf(angle_difference(yaw_now, pocket_yaw)) < 0.01
	var posed_cut: bool = bool(carry.state().carried) and dist < 1.0 and here == 1292 and same_yaw
	if not check(posed_cut, "Human with a blade is posed in region 1292, at %s local %s region %s dist %s yaw %s/%s state %s" % [scene.player.global_position, scene.player.position, here, dist, yaw_now, pocket_yaw, carry.state()]):
		await stop(scene, 1)
		return
	if not check(not blade.relocates_player() and carry.relocates_player(), "the blade card stays and the carry relocates"):
		await stop(scene, 1)
		return
	var cleared: Dictionary = run.state()
	cleared.exit_region = -1
	scene.quest_state["l17_cavern_run"] = cleared
	for i in 20:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	if not check(region_of(scene) == 1292 and flat(scene.player.position, LAND) < 2.0, "settling stays in region 1292"):
		await stop(scene, 1)
		return
	if not await walk(scene, WALK, "exit block to region 1312"):
		await stop(scene, 1)
		return
	await process_frame
	var reached: bool = region_of(scene) == 1312 and flat(scene.player.position, FORWARD) < 8.0
	reached = reached and int(run.state().exit_region) == 1312 and scene.area_id == "L17_HC"
	reached = reached and not run.relocates_player()
	if not check(reached, "region 1312 is reached on foot and the scene stays on L17"):
		await stop(scene, 1)
		return
	var save := "res://tmp/l17_beast_carry_earned_save.json"
	if not check(str(scene._quicksave_unrecorded(save)).is_empty(), "carry save"):
		await stop(scene, 1)
		return
	if not check(str(scene._quickload_unrecorded(save)).is_empty(), "carry reload"):
		await stop(scene, 1)
		return
	carry = scene.get_node("L17BeastCarry")
	run = scene.get_node("L17CavernRun")
	prepare(scene)
	await process_frame
	if not check(bool(carry.state().carried) and int(run.state().exit_region) == 1312, "save keeps the carry and region 1312"):
		await stop(scene, 1)
		return
	var before_log: int = scene.progression.native_log.size()
	var before_route: int = scene.progression.route_log.size()
	scene.player.position = SLIVER
	scene.player.velocity = Vector3.ZERO
	var posed: bool = false
	var saw_hive: bool = false
	var saw_group: bool = false
	for i in 30:
		await physics_frame
		if flat(scene.player.global_position, READER) < 1.0:
			posed = true
		for n in range(before_log, scene.progression.native_log.size()):
			var entry: Dictionary = scene.progression.native_log[n]
			if str(entry.get("archive", "")) == "HIVE4.MIX":
				saw_hive = true
		for n in range(before_route, scene.progression.route_log.size()):
			var fired: Dictionary = scene.progression.route_log[n]
			if str(fired.get("object", "")) == "region:1293" and int(fired.get("event", -1)) == 2:
				saw_group = true
		if posed and saw_hive and saw_group:
			break
	var yaw: float = -TAU * 18386.0 / 65536.0
	var read: bool = posed and saw_hive and saw_group and region_of(scene) == 1259
	read = read and absf(angle_difference(scene.player.rotation.y, yaw)) < 0.01 and scene.area_id == "L17_HC"
	if not check(read, "region 1293 poses the opcode 18 words in region 1259 and HIVE4 stays a room request"):
		print("CARRY reader ", scene.player.global_position, " region ", region_of(scene), " hive ", saw_hive, " group ", saw_group)
		await stop(scene, 1)
		return
	print("PASS earned strand cut poses region 1292, the walk reaches region 1312, and region 1293 poses the opcode 18 words")
	await stop(scene, 0)
