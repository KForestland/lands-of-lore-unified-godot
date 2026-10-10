extends MeshInstance3D
## Source quest prop215. Visual review only until warrior dispatch is connected.
const ROOT := "res://assets/lol2/generated/hive_pillar/"
var origin := Vector3.ZERO
var destination := Vector3.ZERO
var moving := false
var opened := false
var elapsed := 0.0
var blocker: StaticBody3D
const DURATION := 1.0 # Authored preview time; native timing is not established.

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"pillar.json"))
	origin = Vector3(data.position[0],data.position[1],data.position[2])
	destination = Vector3(data.target[0],data.target[1],data.target[2])
	position = origin
	var quad := QuadMesh.new()
	quad.size = Vector2(data.right-data.left,data.top-data.bottom)
	quad.center_offset = Vector3((data.right+data.left)/2.0,(data.top+data.bottom)/2.0,0)
	mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT+"pillar.png"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if int(data.frame_flags) & 64:
		material.uv1_scale.x = -1
		material.uv1_offset.x = 1
	material_override = material
	blocker = StaticBody3D.new()
	add_child(blocker)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 20 # Authored collision approximation for the original sprite.
	cylinder.height = 128
	shape.shape = cylinder
	shape.position.y = 64
	blocker.add_child(shape)

func apply_actor_event(actor_index: int, event: int) -> bool:
	# Verified ADDE0 source lists: either warrior's event10 queues its pillar group.
	# Combat must supply this event; a generic hit or unrelated actor cannot open it.
	if event != 10: return false
	match actor_index:
		32: return apply_source_group(10414)
		34: return apply_source_group(10510)
	return false

func apply_source_group(group: int) -> bool:
	# Either source group carries the same prop215 movement. Not a defeat API:
	# caller must establish actual event acceptance before dispatching this.
	if group not in [10414,10510] or moving or opened or get_tree().paused: return false
	moving = true
	blocker.collision_layer = 0 # Clear before moving; avoid pushing/trapping the player.
	elapsed = 0
	return true

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not moving or get_tree().paused or not is_finite(delta): return
	elapsed = minf(elapsed+maxf(delta,0),DURATION)
	position = origin.lerp(destination,elapsed/DURATION)
	if elapsed == DURATION:
		moving = false
		opened = true
