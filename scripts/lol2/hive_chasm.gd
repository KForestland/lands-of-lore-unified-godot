extends Node3D
## Source rock233/group1680. Hit shape, one-hit activation and timing are authored.
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
const ROOT := "res://assets/lol2/generated/hive_chasm/"
var data: Dictionary
var activated := false
var elapsed := 0.0
var floors: Array[AnimatableBody3D] = []
var trigger: StaticBody3D
var rubble: Node3D
var rubble_material: StandardMaterial3D
var frames: Array[AtlasTexture] = []
var rendered_frame := -1
var configured := false
var completed: bool:
	get: return activated and elapsed == Quests.CHASM_DURATION

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"chasm.json"))
	trigger = StaticBody3D.new()
	trigger.position = Vector3(data.trigger.position[0],data.trigger.position[1],data.trigger.position[2])
	trigger.collision_layer = 4
	trigger.set_meta("hive_chasm",233)
	add_child(trigger)
	var hit_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = (data.trigger.right-data.trigger.left)/2.0
	cylinder.height = data.trigger.top-data.trigger.bottom
	hit_shape.shape = cylinder
	hit_shape.position.y = (data.trigger.top+data.trigger.bottom)/2.0
	trigger.add_child(hit_shape)
	# The parent constructs source materials after child _ready callbacks.
	configure.call_deferred()

func configure() -> void:
	var review = get_parent()
	for floor_data in data.floors:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(review.materials[floor_data.material])
		var collision := PackedVector3Array()
		for i in [0,1,2,0,2,3]:
			var p = floor_data.points[i]
			var vertex := Vector3(p[0],p[1],p[2])
			surface.set_uv(Vector2(floor_data.uv[i][0],floor_data.uv[i][1]))
			surface.add_vertex(vertex)
			collision.append(vertex)
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.name = "ChasmFloor_%d" % int(floor_data.region)
		body.set_meta("target_rise",float(floor_data.target_height)+600.0)
		add_child(body)
		body.add_child(mesh)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(collision)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		floors.append(body)
	var atlas := ImageTexture.create_from_image(Image.load_from_file(ROOT+"rubble.png"))
	for i in range(int(data.frame_count)):
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2((i%int(data.atlas_columns))*data.frame_size[0],(i/int(data.atlas_columns))*data.frame_size[1],data.frame_size[0],data.frame_size[1])
		frames.append(frame)
	rubble_material = StandardMaterial3D.new()
	rubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	rubble_material.alpha_scissor_threshold = 0.5
	rubble_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rubble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rubble_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	rubble = Node3D.new()
	add_child(rubble)
	for source in data.rubble:
		var sprite := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(data.rubble_size[0],data.rubble_size[1])
		quad.center_offset.y = data.rubble_size[1]/2.0
		sprite.mesh = quad
		sprite.material_override = rubble_material
		sprite.position = Vector3(source.position[0],source.position[1],source.position[2])
		rubble.add_child(sprite)
	configured = true
	apply_presentation()

func activate() -> bool:
	if activated or not configured or not get_parent().get_node("Warriors").active(): return false
	activated = true
	elapsed = 0.0
	get_parent().get_node("Nest").chasm_handoff()
	apply_presentation()
	return true

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not configured or not activated or completed or get_tree().paused or not is_finite(delta): return
	elapsed = minf(elapsed+maxf(delta,0),Quests.CHASM_DURATION)
	apply_presentation()

func apply_presentation() -> void:
	trigger.collision_layer = 0 if activated else 4
	if not configured: return
	for body in floors:
		body.visible = activated
		body.collision_layer = 1 if activated else 0
		body.position.y = float(body.get_meta("target_rise"))*elapsed/Quests.CHASM_DURATION
	rubble.visible = activated and not completed
	var frame := mini(int(elapsed*15.0),frames.size()-1)
	if frame != rendered_frame:
		rubble_material.albedo_texture = frames[frame]
		rendered_frame = frame
	for sprite in get_parent().get_node("SourcePropCandidates").instances:
		if int(sprite.get_meta("source_record")) in [229,230,231,232,233]: sprite.visible = not activated

func checkpoint() -> Dictionary:
	return {"activated":activated,"elapsed":elapsed}

func restore(state: Dictionary) -> void:
	activated = state.activated
	elapsed = float(state.elapsed)
	apply_presentation()
