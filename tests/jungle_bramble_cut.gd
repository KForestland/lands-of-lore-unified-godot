extends RefCounted
## One shared cut for the earned Jungle walks. A solid bramble within sword
## reach is aimed and left-clicked, the same strike the player uses. One click
## is one state step. The wall stays solid until the third cut, then the walk
## crosses it before timer 0 grows it back. No teleport and no E.
const IDS: Array[int] = [101, 102, 103, 104, 105, 106, 107, 108, 109]
const REACH := 140.0

static func cut(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var bramble_v: Variant = scene.get("bramble")
	if not bramble_v is Node or not is_instance_valid(bramble_v):
		return
	var bramble: Node = bramble_v
	if int(scene.get("player_form")) == 0 and str(scene.get("equipped_item")) == "":
		return
	var assemblies_v: Variant = scene.get("static_assemblies")
	if not assemblies_v is Node:
		return
	var bodies_v: Variant = (assemblies_v as Node).get("solid_bodies")
	if not bodies_v is Dictionary:
		return
	var bodies: Dictionary = bodies_v
	var player_v: Variant = scene.get("player")
	var camera_v: Variant = scene.get("camera")
	if not player_v is Node3D or not camera_v is Node3D:
		return
	var player: Node3D = player_v
	var camera: Node3D = camera_v
	var best_id := -1
	var best_at := Vector3.ZERO
	var best_distance := REACH + 1.0
	for id in IDS:
		if not bool(bramble.call("solid", id)):
			continue
		var body_v: Variant = bodies.get(id, null)
		if not body_v is StaticBody3D:
			continue
		var at: Vector3 = (body_v as StaticBody3D).global_position
		var distance := player.global_position.distance_to(at)
		if distance <= REACH and distance < best_distance:
			best_distance = distance
			best_id = id
			best_at = at
	if best_id < 0:
		return
	var flat := Vector2(best_at.x, best_at.z) - Vector2(player.global_position.x, player.global_position.z)
	if flat.length() > 0.5:
		player.rotation.y = atan2(-flat.x, -flat.y)
	camera.look_at(best_at, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	bramble._unhandled_input(event)
