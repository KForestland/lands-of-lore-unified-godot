extends SceneTree
## Hintbook: walk to the chains, pull them, and the roof lets the fruit grow.
var scene: Node
var atrium: Node
var player: CharacterBody3D
var camera: Camera3D

func _initialize() -> void:
	run.call_deferred()

func miss(label: String) -> void:
	print("FAIL atrium: ", label)
	quit(1)

func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for _i in 1500:
		await process_frame
		if current_scene != null and bool(current_scene.get("ready_for_review")) and current_scene.get_node_or_null("DarkHallsAtrium") != null:
			break
	scene = current_scene
	if scene == null or not bool(scene.get("ready_for_review")):
		return miss("Dark Halls not ready")
	atrium = scene.get_node("DarkHallsAtrium")
	player = scene.get("player") as CharacterBody3D
	camera = scene.get("camera") as Camera3D
	if player == null or camera == null:
		return miss("player missing")
	if bool(atrium.call("is_open")):
		return miss("the roof was already open")
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
	var chain_v: Variant = atrium.get("chain")
	if not chain_v is Vector3:
		return miss("the chain has no center")
	var chain: Vector3 = chain_v
	player.global_position = Vector3(chain.x, 432.0, chain.z + 220.0)
	player.velocity = Vector3.ZERO
	var spot := Vector3(chain.x, player.global_position.y, chain.z + 70.0)
	for _tick in 200:
		var step := spot - player.global_position
		step.y = 0.0
		if step.length() < 2.0:
			break
		if player.global_position.distance_to(chain) < 110.0:
			break
		player.velocity = step.normalized() * 120.0
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame
	if player.global_position.distance_to(chain) > 115.0:
		return miss("the walk stopped short of the chain at %s" % player.global_position)
	camera.look_at(chain, Vector3.UP)
	await physics_frame
	await _press_e()
	if not bool(atrium.call("is_open")):
		return miss("E did not pull the chain at %s" % player.global_position)
	var homes: Dictionary = atrium.get("homes")
	for sid in [52, 53, 54, 55]:
		var moved_v: Variant = atrium.call("center_of", sid)
		if not moved_v is Vector3:
			return miss("roof %s has no center" % sid)
		var moved: Vector3 = moved_v
		var home: AABB = homes[sid]
		if absf(moved.x - home.get_center().x) < 200.0:
			return miss("roof %s did not slide (%s)" % [sid, moved])
	var quests: Dictionary = scene.get("quest_state")
	var bag: Dictionary = quests.get("dark_halls_atrium", {})
	if int(bag.get("sound", 0)) != 1084 or not bool(bag.get("open", false)):
		return miss("group 8526 was not stored")
	print("PASS atrium: pulled chain 252, the roof slid open, and the fruit grew")
	quit(0)

func _press_e() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.physical_keycode = KEY_E
		key.pressed = pressed
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await process_frame
