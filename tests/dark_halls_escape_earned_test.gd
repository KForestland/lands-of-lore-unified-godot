extends SceneTree
## Hintbook escape: shove a crystal crate to the seven-o'clock window and Spark it.
## Group 8280 is opcode 197 arm 10 on region 1413. The orb end stays the other way out.
const Rules = preload("res://scripts/lol2/dark_halls_blast_rules.gd")
## After the crate slides east off the west wall, these centers stay on the open floor.
const PATH: Array[Vector2] = [
	Vector2(-1248, -160),
	Vector2(-1312, -160), Vector2(-1376, -160), Vector2(-1440, -160), Vector2(-1504, -160),
	Vector2(-1568, -160), Vector2(-1632, -160), Vector2(-1696, -160), Vector2(-1760, -160),
	Vector2(-1824, -160), Vector2(-1888, -160), Vector2(-1952, -160), Vector2(-2016, -160),
	Vector2(-2080, -160), Vector2(-2144, -112), Vector2(-2208, -112), Vector2(-2272, -96),
	Vector2(-2320, -48), Vector2(-2368, 0), Vector2(-2416, 48), Vector2(-2464, 96),
	Vector2(-2512, 144), Vector2(-2560, 192), Vector2(-2608, 240), Vector2(-2656, 288),
]
var scene: Node
var crates: Node
var windows: Node
var player: CharacterBody3D
var camera: Camera3D
var magic: Node
var blast: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func miss(label: String) -> void:
	print("FAIL escape: ", label)
	quit(1)

func run() -> void:
	var fields: Dictionary = load("res://scripts/lol2/dark_halls_crates.gd").exit_group_fields("c59085050a00")
	if int(fields.get("arm", 0)) != 10 or int(fields.get("region", 0)) != 1413 or int(fields.get("list_byte_0x09", 0)) != 1:
		return miss("group 8280 was not opcode 197 arm 10 on region 1413")
	if not load("res://scripts/lol2/dark_halls_crates.gd").exit_group_fields("c5901e000000").is_empty():
		return miss("a different opcode 197 counted as the exit")
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for _i in 1500:
		await process_frame
		if current_scene != null and bool(current_scene.get("ready_for_review")) and current_scene.get_node_or_null("DarkHallsCrates") != null and current_scene.get_node_or_null("DarkHallsWindows") != null:
			break
	scene = current_scene
	if scene == null or not bool(scene.get("ready_for_review")):
		return miss("Dark Halls not ready")
	crates = scene.get_node("DarkHallsCrates")
	windows = scene.get_node("DarkHallsWindows")
	player = scene.get("player") as CharacterBody3D
	camera = scene.get("camera") as Camera3D
	magic = scene.get("starting_magic") as Node
	if player == null or camera == null or magic == null:
		return miss("player missing")
	if bool(scene.call("exits_open")) or bool(windows.call("done")):
		return miss("exits were already open")
	blast = JSON.parse_string(FileAccess.get_file_as_string(Rules.SOURCE))
	var window: Vector3 = windows.call("exit_center")
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/dark_halls_crates_source.json")).crates
	for row_v in rows:
		var row: Dictionary = row_v
		var id := int(row.control)
		if Rules.damage(crates.call("center_of", id), window, blast) != 0:
			return miss("crate %d already reaches window 246" % id)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false)
	player.set_physics_process(false)
	for node_name in ["DarkHallsCreatures", "DarkHallsRoute"]:
		var extra := scene.get_node_or_null(node_name)
		if extra != null:
			extra.set_physics_process(false)
			extra.set_process(false)
			for body in extra.find_children("", "CollisionObject3D", true, false):
				(body as CollisionObject3D).collision_layer = 0
				(body as CollisionObject3D).collision_mask = 0
	var rix: Variant = scene.get("rix")
	if rix is Node:
		(rix as Node).set_physics_process(false)
		(rix as Node).set_process(false)
	var home: Vector3 = crates.call("center_of", 449)
	var half: Vector3 = crates.call("half_of", 449)
	# North of the crate. The west face sits on a wall, so the open and the first shove face south.
	_place(Vector3(home.x, home.y - half.y + 32.0, home.z + half.z + 36.0))
	camera.look_at(home, Vector3.UP)
	await physics_frame
	await _press_e()
	if int(crates.call("state_of", 449)) != 1:
		return miss("E did not open crate 449, aimed %s at %s" % [str(crates.call("aimed_id")), player.global_position])
	# The west wall leaves no room to stand beside the crate, so the press walks into that side and the crate slides east.
	var slid := false
	for _tick in 50:
		var now := crates.call("center_of", 449) as Vector3
		if now.x <= -1252.0:
			slid = true
			break
		var stand := Vector3(now.x - 18.0, player.global_position.y, now.z)
		if player.global_position.z < now.z - 2.0:
			stand.z = now.z + 8.0
		var step := stand - player.global_position
		step.y = 0.0
		player.velocity = step.normalized() * 90.0 if step.length() > 0.2 else Vector3(-40.0, 0, 0)
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
	if not slid:
		return miss("crate 449 did not slide east, at %s player %s" % [crates.call("center_of", 449), player.global_position])
	var step_i := 0
	var last_move := Vector3.ZERO
	for _tick in 2400:
		if step_i >= PATH.size():
			break
		var wp: Vector2 = PATH[step_i]
		var now: Vector3 = crates.call("center_of", 449)
		var remain := Vector2(wp.x - now.x, wp.y - now.z)
		if remain.length() < 16.0:
			step_i += 1
			continue
		var dir := Vector3(remain.x, 0.0, remain.y).normalized()
		last_move = dir
		var stand := Vector3(now.x, player.global_position.y, now.z) - dir * 26.0
		var step := stand - player.global_position
		step.y = 0.0
		player.velocity = step.normalized() * 140.0 if step.length() > 0.3 else dir * 40.0
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
	var parked: Vector3 = crates.call("center_of", 449)
	var at_window := Rules.damage(parked, window, blast)
	if at_window <= 0 or step_i < PATH.size() - 2:
		return miss("crate 449 stopped at %s after waypoint %d, blast %d, player %s" % [parked, step_i, at_window, player.global_position])
	if last_move.length_squared() < 0.01:
		last_move = Vector3(-1, 0, 0)
	var retreat := player.global_position - last_move * 110.0
	for _tick in 80:
		var step := retreat - player.global_position
		step.y = 0.0
		if step.length() < 1.0:
			break
		player.velocity = step.normalized() * 140.0
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
	camera.look_at(parked, Vector3.UP)
	await physics_frame
	var hp := int(magic.call("health"))
	var expect := Rules.damage(parked, player.global_position, blast)
	magic.call("spark", 3)
	await physics_frame
	var hp2 := int(magic.call("health"))
	if int(crates.call("state_of", 449)) != 2:
		return miss("level 3 Spark left crate 449")
	if not bool(scene.call("exits_open")) or bool(windows.call("done")):
		return miss("the exit did not open, or the orb end ran")
	if expect <= 0 or hp2 <= 0 or hp2 != hp - expect:
		return miss("falloff health %s -> %s, expected drop %s" % [hp, hp2, expect])
	var quests: Dictionary = scene.get("quest_state")
	var bag: Dictionary = quests.get("dark_halls_crates", {})
	var stored: Dictionary = bag.get("exit_group", {})
	if int(bag.get("blast_exit", 0)) != 1 or int(stored.get("arm", 0)) != 10 or int(stored.get("region", 0)) != 1413:
		return miss("group 8280 was not stored")
	# Region 1413 is past the window sill and a 10-unit curb. The capsule stops on the near side.
	var spot := Vector3(-2664.0, player.global_position.y, 248.0)
	var still := 0
	for _tick in 250:
		var step := spot - player.global_position
		step.y = 0.0
		if step.length() < 6.0:
			break
		player.velocity = step.normalized() * 120.0
		player.velocity.y = -40.0
		var before := player.global_position
		player.move_and_slide()
		await physics_frame
		var moved := Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length()
		if moved < 0.2:
			still += 1
		else:
			still = 0
		if still > 30:
			break
	var here := Vector2(player.global_position.x, player.global_position.z)
	var pane := Vector2(window.x, window.z)
	var dist := here.distance_to(pane)
	if dist > 150.0:
		return miss("the walk stopped short of window 246 at %s, %.0f away" % [player.global_position, dist])
	if not bool(scene.call("exits_open")) or bool(windows.call("done")):
		return miss("the exit closed on the way to the pane")
	print("PASS escape: crate 449 shoved to window 246, level-3 Spark dealt %d, and the exit opened %.0f from the pane" % [expect, dist])
	quit(0)

func _place(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO

func _press_e() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.physical_keycode = KEY_E
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await process_frame
