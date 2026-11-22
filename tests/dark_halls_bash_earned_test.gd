extends SceneTree
## Hintbook 2477-2479: chop through a door. Walk to door 56 and chop it open. Walk into the trap,
## the door slams, then three chops swing that leaf too. The quest lock stays until shade 73 dies.
const Assemblies = preload("res://scripts/lol2/static_assemblies.gd")
var scene: Node
var doors: Node
var player: CharacterBody3D

func _initialize() -> void:
	run.call_deferred()

func miss(label: String) -> void:
	print("FAIL bash: ", label)
	quit(1)

func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for _i in 1500:
		await process_frame
		if current_scene != null and bool(current_scene.get("ready_for_review")) and current_scene.get_node_or_null("DarkHallsDoors") != null:
			break
	scene = current_scene
	if scene == null or not bool(scene.get("ready_for_review")):
		return miss("Dark Halls not ready")
	doors = scene.get_node("DarkHallsDoors")
	player = scene.get("player") as CharacterBody3D
	if player == null or (doors.get("leaves") as Dictionary).size() != 2:
		return miss("door host missing")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for node_name in ["DarkHallsCreatures", "DarkHallsRoute"]:
		var extra := scene.get_node_or_null(node_name)
		if extra != null:
			extra.set_physics_process(false)
			extra.set_process(false)
			for body in extra.find_children("", "CollisionObject3D", true, false):
				(body as CollisionObject3D).collision_layer = 0
				(body as CollisionObject3D).collision_mask = 0
	var pop: Node = scene.get_node("DarkHallsCreatures")
	var home24: Array = (pop.get("state") as Dictionary).actors["24"].position
	if not await _chop_open("56", Vector3(-2750.0, 117.0, -2459.0), Vector3(-2682.0, 117.0, -2459.0)):
		return
	if int(_local(6)) != 1:
		return miss("door 56 did not set local 6")
	if bool(doors.call("is_locked", "56")):
		return miss("door 56 came up locked")
	var spot := Vector3(-1628.0, 342.0, -1800.0)
	var trap := Vector3(-1628.0, 342.0, -1867.0)
	player.global_position = spot
	player.velocity = Vector3.ZERO
	await _walk(trap)
	for _i in 8:
		await physics_frame
	if player.global_position.distance_to(trap) > 30.0:
		return miss("the walk stopped outside the trap at %s" % player.global_position)
	if not bool((doors.call("state") as Dictionary).get("trap", false)) or not bool(doors.call("is_locked", "57")):
		return miss("the trap did not slam at %s" % player.global_position)
	if bool(doors.call("is_open", "57")):
		return miss("the slammed door stayed open")
	if str(doors.get("trap_group")) != "unhosted" or not str(doors.get("trap_reason")).contains("index 12"):
		return miss("group 794 status %s %s" % [doors.get("trap_group"), doors.get("trap_reason")])
	if int(doors.get("native").call("field", "movable:57", "byte_0x25", -1)) != 2:
		return miss("the trap did not write state 2")
	var shade: Array = (pop.get("state") as Dictionary).actors["73"].position
	var actor_to: Array = (doors.get("source") as Dictionary).trap.actor_to
	if Vector2(float(shade[0]) - float(actor_to[0]), float(shade[2]) - float(actor_to[1])).length() > 1.0:
		return miss("shade 73 stayed at %s" % shade)
	var later24: Array = (pop.get("state") as Dictionary).actors["24"].position
	if Vector2(float(later24[0]) - float(home24[0]), float(later24[2]) - float(home24[2])).length() > 1.0:
		return miss("shade 24 was moved")
	# Assembly 260 fills the south side of the trap. The open lane is the east gap.
	for corner in [Vector3(-1628.0, 342.0, -1845.0), Vector3(-1575.0, 342.0, -1845.0), Vector3(-1575.0, 342.0, -2031.0), Vector3(-1595.0, 342.0, -2031.0)]:
		await _walk(corner)
		if player.global_position.distance_to(corner) > 24.0:
			return miss("the walk to door 57 stopped at %s" % player.global_position)
	if not await _chop_leaf("57", player.global_position):
		return
	if not bool(doors.call("is_locked", "57")) or bool(doors.call("is_open", "57")):
		return miss("the bash cleared the quest lock")
	if int(doors.get("native").call("field", "movable:57", "travel_0x50", -1)) != 21845:
		return miss("the slammed door did not take travel 21845")
	if int(_local(2)) != 1:
		return miss("door 57 did not set local 2")
	if _blocked(_row("57")):
		return miss("the chopped leaf still fills the doorway")
	print("PASS bash: walked to door 56 and chopped it open, walked into the trap, and three chops swung the slammed door")
	quit(0)

func _row(id: String) -> Dictionary:
	for row in (doors.get("source") as Dictionary).doors:
		if str(int(row.movable)) == id:
			return row
	return {}

func _local(index: int) -> int:
	return int(((doors.get("native") as RefCounted).get("locals") as Dictionary).get(index, -1))

func _walk(spot: Vector3) -> void:
	for _tick in 140:
		var step := spot - player.global_position
		step.y = 0.0
		if step.length() < 8.0:
			break
		player.velocity = step.normalized() * 90.0
		player.velocity.y = -40.0
		player.move_and_slide()
		await physics_frame

func _aim(id: String) -> void:
	var leaf := (doors.get("leaves") as Dictionary)[id].hinge.get_node("Leaf") as Node3D
	(scene.get("camera") as Camera3D).look_at(leaf.global_position)
	await physics_frame

func _chop() -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await process_frame

func _settle() -> void:
	for _i in 80:
		await physics_frame

func _chop_open(id: String, start: Vector3, stand: Vector3) -> bool:
	player.global_position = start
	player.velocity = Vector3.ZERO
	await _walk(stand)
	if player.global_position.distance_to(stand) > 20.0:
		miss("door %s walk stopped at %s" % [id, player.global_position])
		return false
	return await _chop_leaf(id, player.global_position)

func _chop_leaf(id: String, stand: Vector3) -> bool:
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await _aim(id)
	if str(doors.call("aimed")) != id:
		miss("door %s was not in front of the camera at %s" % [id, player.global_position])
		return false
	for _hit in 3:
		await _aim(id)
		await _chop()
	await _settle()
	var leaf: Node3D = (doors.get("leaves") as Dictionary)[id].hinge
	var degrees := absf(rad_to_deg(leaf.rotation.y))
	if absf(degrees - 21845.0 * 360.0 / 65536.0) > 1.0:
		miss("door %s leaf stopped at %.2f" % [id, degrees])
		return false
	if id == "56" and not bool(doors.call("is_open", id)):
		miss("door 56 stayed shut in the quest")
		return false
	return true

func _blocked(row: Dictionary) -> bool:
	var origin := Vector3(row.origin[0], row.origin[1], row.origin[2]) + Vector3(0, float(row.size[1]) / 2.0, 0)
	var yaw := -float(row.heading) / 65536.0 * TAU
	var normal := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var query := PhysicsRayQueryParameters3D.create(origin - normal * 30.0, origin + normal * 30.0, Assemblies.SCENERY_LAYER)
	return not scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
