extends Node3D
## Source gate77 artwork/target; modern edge hinge and moving collision.
const ROOT := "res://assets/lol2/generated/museum_gate/"
var available := false
var target_open := false
var progress := 0.0
var travel_radians := 0.0
var pivot: AnimatableBody3D

static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT + "gate.json") and FileAccess.file_exists(ROOT + "gate.png")

func _ready() -> void:
	if not assets_ready(): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "gate.json"))
	position = Vector3(data.position[0], data.position[1], data.position[2])
	travel_radians = float(data.travel_angle_units) * TAU / 65536.0
	pivot = AnimatableBody3D.new()
	pivot.sync_to_physics = false
	pivot.position.x = -float(data.width) / 2.0
	add_child(pivot)
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(data.width, data.height)
	quad.center_offset = Vector3(float(data.width) / 2.0, float(data.height) / 2.0, 0)
	panel.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + "gate.png"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel.material_override = material
	pivot.add_child(panel)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(data.width, data.height, 2.0)
	collision.shape = shape
	collision.position = quad.center_offset
	pivot.add_child(collision)
	available = true

func open() -> void:
	target_open = true

func reset() -> void:
	target_open = false
	progress = 0
	if available: pivot.rotation.y = 0

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not available: return
	progress = move_toward(progress, 1.0 if target_open else 0.0, maxf(delta, 0) / 1.2)
	pivot.rotation.y = -progress * travel_radians

func checkpoint() -> Dictionary:
	return {"target_open": target_open, "progress": progress}

func restore_checkpoint(state: Dictionary) -> void:
	target_open = bool(state.get("target_open", false))
	progress = clampf(float(state.get("progress", 0)), 0, 1)
	if available: pivot.rotation.y = -progress * travel_radians
