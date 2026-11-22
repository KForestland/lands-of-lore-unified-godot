extends SceneTree
## Owner r17 17-17-34 and 17-18-15. Walk crate 448 like the hintbook: it is solid, E shows the
## crystals, a shove stops on the steel door, a step back and level-three Spark use the original
## falloff, and the door is gone. Crate 943 is the overlapping storeroom pile.
const Rules = preload("res://scripts/lol2/dark_halls_blast_rules.gd")
var scene: Node
var crates: Node
var player: CharacterBody3D
var camera: Camera3D
var magic: Node
var blast: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func miss(label: String) -> void:
	print("FAIL crates: ", label)
	quit(1)

func run() -> void:
	blast = JSON.parse_string(FileAccess.get_file_as_string(Rules.SOURCE))
	if Rules.damage(Vector3(-1243, 750, -530), Vector3(-1243, 750, -614), blast) != 23:
		return miss("source crate 448 to door 84 is not damage 23")
	var prefix: Dictionary = load("res://scripts/lol2/dark_halls_crates.gd").prefix_fields(["cc906800f9010300", "c5901e000000", "091056000300"])
	if int(prefix.get("region30_byte_1c_bit01", -1)) != 0 or int(prefix.get("hole86_target", 0)) != 86 or int(prefix.get("opcode204_entry", 0)) != 505:
		return miss("control 973 prefix was dropped")
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for _i in 1500:
		await process_frame
		if current_scene != null and bool(current_scene.get("ready_for_review")) and current_scene.get("starting_magic") != null and current_scene.get_node_or_null("DarkHallsCrates") != null:
			break
	scene = current_scene
	if scene == null or not bool(scene.get("ready_for_review")):
		return miss("Dark Halls not ready")
	crates = scene.get_node_or_null("DarkHallsCrates")
	if crates == null:
		return miss("crate host missing")
	player = scene.get("player") as CharacterBody3D
	camera = scene.get("camera") as Camera3D
	magic = scene.get("starting_magic") as Node
	if player == null or camera == null or magic == null:
		return miss("player missing")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false)
	player.set_physics_process(false)
	for node_name in ["DarkHallsCreatures", "DarkHallsRoute"]:
		var extra := scene.get_node_or_null(node_name)
		if extra != null:
			extra.set_physics_process(false)
			extra.set_process(false)
	var rix: Variant = scene.get("rix")
	if rix is Node:
		(rix as Node).set_physics_process(false)
		(rix as Node).set_process(false)
	var home := crates.call("center_of", 448) as Vector3
	var half := crates.call("half_of", 448) as Vector3
	var door_c := crates.call("door_center_of") as Vector3
	var door_h := crates.call("door_half_of") as Vector3
	if not bool(crates.call("door_blocking")):
		return miss("steel door was already open")
	_place(Vector3(home.x, home.y - half.y + 32.0, home.z + half.z + 40.0))
	camera.look_at(home, Vector3.UP)
	await physics_frame
	magic.call("spark", 3)
	await physics_frame
	if int(crates.call("state_of", 448)) != 0 or not bool(crates.call("door_blocking")):
		return miss("closed crate detonated")
	await _press_e()
	if int(crates.call("state_of", 448)) != 1 or not bool(crates.call("crystal_on", 448)):
		return miss("E did not show the crystals, aimed %s" % str(crates.call("aimed_id")))
	if (crates.call("center_of", 448) as Vector3).distance_squared_to(home) > 0.1:
		return miss("opening moved the crate")
	magic.call("spark", 1)
	await physics_frame
	if int(crates.call("state_of", 448)) != 1:
		return miss("level 1 Spark detonated the crate")
	var shoved := false
	var blocked := false
	for _tick in 90:
		var step := Vector3(home.x, player.global_position.y, door_c.z) - player.global_position
		step.y = 0.0
		player.velocity = step.normalized() * 90.0 if step.length() > 0.2 else Vector3.ZERO
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
		var now := crates.call("center_of", 448) as Vector3
		var gap := (now.z - half.z) - (door_c.z + door_h.z)
		if now.z < home.z - 40.0:
			shoved = true
		if player.global_position.z > now.z + 8.0:
			blocked = true
		if gap < 1.5 and gap > -0.5 and shoved:
			break
	var parked := crates.call("center_of", 448) as Vector3
	var gap := (parked.z - half.z) - (door_c.z + door_h.z)
	if not shoved or not blocked:
		return miss("walk did not shove crate 448 (player %s crate %s)" % [player.global_position, parked])
	if gap > 1.5 or gap < -0.5:
		return miss("crate stopped %s from the door" % gap)
	if player.global_position.z < parked.z:
		return miss("player passed through crate 448")
	if not bool(crates.call("door_blocking")):
		return miss("door opened before the blast")
	var retreat := Vector3(parked.x, player.global_position.y, parked.z + 140.0)
	for _tick in 80:
		var step := retreat - player.global_position
		step.y = 0.0
		if step.length() < 1.0:
			break
		player.velocity = step.normalized() * 120.0
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
	var apart := Vector2(player.global_position.x - parked.x, player.global_position.z - parked.z).length()
	if apart < 80.0:
		return miss("could not step back, distance %s" % apart)
	camera.look_at(parked, Vector3.UP)
	await physics_frame
	var hp := int(magic.call("health"))
	var expect := Rules.damage(parked, player.global_position, blast)
	magic.call("spark", 3)
	await physics_frame
	var hp2 := int(magic.call("health"))
	if int(crates.call("state_of", 448)) != 2 or bool(crates.call("crystal_on", 448)):
		return miss("level 3 Spark left crate 448")
	if bool(crates.call("door_blocking")):
		return miss("steel door still blocks")
	if expect <= 0 or hp2 <= 0 or hp2 != hp - expect:
		return miss("falloff health %s -> %s, expected drop %s at %s" % [hp, hp2, expect, apart])
	var through := Vector3(door_c.x, player.global_position.y, door_c.z - door_h.z - 20.0)
	var crossed := false
	for _tick in 160:
		var step := through - player.global_position
		step.y = 0.0
		player.velocity = step.normalized() * 120.0 if step.length() > 0.2 else Vector3.ZERO
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
		if player.global_position.z < door_c.z - door_h.z - 8.0:
			crossed = true
			break
	if not crossed:
		return miss("door was gone but the walk stopped at %s" % player.global_position)
	if not bool(crates.call("open_crate", 973)) or not bool(crates.call("on_spark", 973, 3)):
		return miss("control 973 blast did not run")
	var quests: Dictionary = scene.get("quest_state")
	var bag: Dictionary = quests.get("dark_halls_crates", {})
	var stored: Dictionary = bag.get("prefix973", {})
	if int(stored.get("hole86_target", 0)) != 86 or int(stored.get("region30_byte_1c_bit01", -1)) != 0:
		return miss("control 973 prefix was not stored")
	if int(magic.call("health")) != hp2:
		return miss("crate 973 damaged the player at the steel door")
	var pile := crates.call("center_of", 943) as Vector3
	var pile_half := crates.call("half_of", 943) as Vector3
	_place(Vector3(pile.x, pile.y - pile_half.y + 32.0, pile.z + pile_half.z + 36.0))
	var pile_home := pile
	var stopped := false
	for _tick in 40:
		player.velocity = Vector3(0, -40, -90)
		player.move_and_slide()
		await physics_frame
		var now := crates.call("center_of", 943) as Vector3
		if player.global_position.z > now.z + 8.0 and player.global_position.distance_to(Vector3(pile_home.x, player.global_position.y, pile_home.z)) < 80.0:
			stopped = true
		if player.global_position.z < now.z:
			return miss("player passed through crate 943")
	if not stopped:
		return miss("crate 943 did not stop the walk at %s" % player.global_position)
	print("PASS crates: crate 448 blocked the walk, opened, shoved to the steel door, level-3 Spark dealt %d, and the door was gone" % expect)
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
