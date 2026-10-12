extends MeshInstance3D
## Source object97 wall; authored collision opening and light cue.
const ROOT := "res://assets/lol2/generated/museum_escape_wall/"
var light_ray: MeshInstance3D
var intact_texture: ImageTexture
var barrier: StaticBody3D
var stage := 0
var reveal_wait := -1.0
var textures: Array[ImageTexture] = []
func _ready() -> void:
	name = "MuseumEscapeWall97"
	position = Vector3(1429,60,-492)
	rotation.y = PI / 2
	var quad := QuadMesh.new()
	quad.size = Vector2(46,60)
	mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material_override = material
	for i in range(1,5): textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + "stage_%d.png" % i)))
	barrier = StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(46,90,4)
	collision.shape = box
	collision.position.y = -15
	barrier.add_child(collision)
	add_child(barrier)
	intact_texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_review/material_31.png"))
	light_ray = MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Crossed translucent shafts; works with the compatibility renderer.
	for axis in [Vector3.RIGHT,Vector3.UP]:
		var near_point := Vector3(0,0,-2.5)
		var far_point := Vector3(0,-18,-65)
		var vertices := [near_point-axis*0.4,near_point+axis*0.4,far_point+axis*8,far_point-axis*8]
		for index in [0,1,2,0,2,3]:
			surface.set_color(Color(0.85,0.9,1.0,0.24 if index < 2 else 0.0))
			surface.add_vertex(vertices[index])
	light_ray.mesh = surface.commit()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	light_ray.material_override = glow
	add_child(light_ray)
	set_stage(0)
func begin_decay() -> void:
	if stage == 0 and reveal_wait < 0: reveal_wait = float(randi_range(5,10))
func _process(delta: float) -> void:
	if reveal_wait < 0: return
	reveal_wait = maxf(0,reveal_wait-delta)
	if reveal_wait == 0:
		reveal_wait = -1
		set_stage(1)
func set_stage(value: int) -> void:
	stage = value
	barrier.collision_layer = 0 if stage == 4 else 1
	visible = true
	mesh.size = Vector2(46,90 if stage == 0 else 60)
	mesh.center_offset.y = -15 if stage == 0 else 0
	material_override.albedo_texture = textures[stage-1] if stage > 0 else intact_texture
	light_ray.visible = stage > 0 and stage < 4
func receive_hit() -> bool:
	if get_tree().paused or stage < 1 or stage >= 4: return false
	# Authored25-point sword strikes cross source condition thresholds75/50/25.
	set_stage(stage+1)
	return true
func checkpoint() -> Dictionary:
	return {"stage":stage,"wait":reveal_wait}
func restore_checkpoint(state: Dictionary) -> void:
	set_stage(int(state.get("stage",0)))
	reveal_wait = float(state.get("wait",-1))
