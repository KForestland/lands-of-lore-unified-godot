extends Node3D
## Original painting54/lever53/grate51; authored movement and interaction controls.
var painting: MeshInstance3D
var lever: MeshInstance3D
var grate: AnimatableBody3D
var painting_moved := false
var gate_open := false
var lever_pulled := false
var progress := 0.0
func _ready() -> void:
	name = "MuseumGallery"
	painting = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(55,40)
	painting.mesh = quad
	painting.position = Vector3(1958,57,-1454)
	painting.rotation.y = PI/2
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_gallery/painting.png"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	painting.material_override = mat
	add_child(painting)
	# Authored recess backing covers geometry omitted with the original mechanism.
	var backing := MeshInstance3D.new()
	var plate := QuadMesh.new()
	plate.size = Vector2(55,40)
	backing.mesh = plate
	backing.position = Vector3(1978,57,-1454)
	backing.rotation.y = PI/2
	var backing_material := StandardMaterial3D.new()
	backing_material.albedo_color = Color(0.12,0.105,0.085)
	backing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	backing.material_override = backing_material
	add_child(backing)
	lever = MeshInstance3D.new()
	var handle := BoxMesh.new()
	handle.size = Vector3(20,4,4)
	lever.mesh = handle
	lever.position = Vector3(1972,67,-1457)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.52,0.43,0.27)
	metal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lever.material_override = metal
	add_child(lever)
	lever.hide()
	grate = AnimatableBody3D.new()
	grate.position = Vector3(1128,0,-948)
	grate.sync_to_physics = false
	add_child(grate)
	for i in range(14):
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(5,120,5)
		bar.mesh = box
		bar.position = Vector3(-65.5+i*10,60,-0.5)
		bar.material_override = metal
		grate.add_child(bar)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(135,120,5)
	collider.shape = shape
	collider.position = Vector3(-0.5,60,-0.5)
	grate.add_child(collider)
func move_painting() -> bool:
	if painting_moved: return false
	painting_moved = true
	painting.position.z -= 60
	lever.show()
	return true
func pull_lever() -> bool:
	if not painting_moved or lever_pulled: return false
	gate_open = true
	lever_pulled = true
	lever.rotation.z = -PI/4
	return true
## Sk-key lock control140: its insert group moves movables53/51 to 100 and sets lever53 state1; its take group
## returns both to 0 and lever53 to state0 (the lever can be pulled again). The lever pose is shown only once the
## painting no longer hides it.
func lock_insert() -> void:
	gate_open = true
	lever_pulled = painting_moved
	lever.rotation.z = -PI/4 if lever_pulled else 0.0
func lock_take() -> void:
	gate_open = false
	lever_pulled = false
	lever.rotation.z = 0
func close_for_hourglass() -> void:
	# Source group4620 targets grate51 only; retain the lever position.
	gate_open = false

func _physics_process(delta: float) -> void:
	progress = move_toward(progress,1.0 if gate_open else 0.0,delta/1.2)
	grate.position.y = progress*125
func checkpoint() -> Dictionary:
	return {"lever_pulled":lever_pulled,"painting_moved":painting_moved,"gate_open":gate_open,"progress":progress}
func restore_checkpoint(state: Dictionary) -> void:
	painting_moved = state.get("painting_moved",false)
	gate_open = state.get("gate_open",false)
	lever_pulled = state.get("lever_pulled",gate_open)
	progress = float(state.get("progress",0))
	painting.position.z = -1514 if painting_moved else -1454
	lever.visible = painting_moved
	lever.rotation.z = -PI/4 if lever_pulled else 0
	grate.position.y = progress*125
