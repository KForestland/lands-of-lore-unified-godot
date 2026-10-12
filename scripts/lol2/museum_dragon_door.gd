extends AnimatableBody3D
## Original door82; authored vertical opening and collision.
var opened := false
var progress := 0.0
func _ready() -> void:
	name = "MuseumDragonDoor82"
	sync_to_physics = false
	position = Vector3(3048,0,-834)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(50,70,5)
	visual.mesh = mesh
	visual.position.y = 35
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_dragon_door/door.png"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	visual.material_override = material
	add_child(visual)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	collider.shape = box
	collider.position.y = 35
	add_child(collider)
func open() -> bool:
	if opened: return false
	opened = true
	return true
func _physics_process(delta: float) -> void:
	if opened:
		progress = minf(1,progress+delta)
		position.y = 80*progress
func checkpoint() -> Dictionary:
	return {"opened":opened,"progress":progress}
func restore_checkpoint(state: Dictionary) -> void:
	opened = state.get("opened",false)
	progress = float(state.get("progress",0))
	position.y = 80*progress
