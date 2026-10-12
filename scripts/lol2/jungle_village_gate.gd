extends Node3D
## Original two-leaf village gate. Source condition and sampled hinge poses;
## modern timing/swept collision. Remaining group4354 effects are separate.
const ROOT := "res://assets/lol2/generated/jungle_village/"
var asset_root := ROOT
const State = preload("res://scripts/lol2/jungle_village_state.gd")
var data: Dictionary
var leaves: Array[StaticBody3D] = []
var meshes: Dictionary = {}
var shapes: Dictionary = {}
var materials: Dictionary = {}
var pose := -1
var was_inside := false
var available := false

static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT+"gates.json") and FileAccess.file_exists(ROOT+"material_0742.png") and FileAccess.file_exists(ROOT+"material_0514.png")

func _ready() -> void:
	if not assets_ready(): return
	data = JSON.parse_string(FileAccess.get_file_as_string(asset_root+"gates.json"))
	for leaf in data.leaves:
		var body := StaticBody3D.new()
		body.name = "Gate%d" % int(leaf.index)
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("source_movable",int(leaf.index))
		add_child(body)
		body.add_child(MeshInstance3D.new())
		body.add_child(CollisionShape3D.new())
		leaves.append(body)
	available = true
	restore()

func state() -> Dictionary:
	var quests: Dictionary = get_parent().quest_state
	if not quests.has("jungle_village"): quests.jungle_village = State.initial()
	return quests.jungle_village

func prepare_pose(percent: int) -> void:
	if meshes.has(percent): return
	var built_meshes: Array[ArrayMesh] = []
	var built_shapes: Array[ConvexPolygonShape3D] = []
	for leaf in data.leaves:
		var mesh := ArrayMesh.new()
		var vertices := PackedVector3Array()
		for face in leaf.frames[percent]:
			if not materials.has(face.material):
				var material := StandardMaterial3D.new()
				material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(asset_root+face.material))
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				materials[face.material] = material
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(materials[face.material])
			for index in [0,1,2,0,2,3]:
				var p: Array = face.vertices[index]
				var point := Vector3(p[0],p[1],p[2])
				surface.set_uv(Vector2(face.uv[index][0],face.uv[index][1]))
				surface.add_vertex(point)
				vertices.append(point)
			surface.commit(mesh)
		var shape := ConvexPolygonShape3D.new()
		shape.points = vertices
		built_meshes.append(mesh)
		built_shapes.append(shape)
	meshes[percent] = built_meshes
	shapes[percent] = built_shapes

func set_pose(percent: int) -> void:
	if percent == pose: return
	prepare_pose(percent)
	for i in leaves.size():
		leaves[i].get_child(0).mesh = meshes[percent][i]
		leaves[i].get_child(1).shape = shapes[percent][i]
	pose = percent

func restore() -> void:
	if not available: return
	set_pose(int(round(float(state().elapsed)/State.DURATION*100.0)))
	was_inside = inside()

func inside() -> bool:
	if not available or not is_instance_valid(get_parent().player): return false
	var player: CharacterBody3D = get_parent().player
	var foot: float = player.position.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	if foot < float(data.floor.min())-2 or foot > float(data.floor.max())+2: return false
	var polygon := PackedVector2Array()
	for point in data.polygon: polygon.append(Vector2(point[0],point[1]))
	return Geometry2D.is_point_in_polygon(Vector2(player.position.x,player.position.z),polygon)

func check_contact() -> bool:
	var parent = get_parent()
	if not available or get_tree().paused or parent.flying or parent.health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not parent.player.is_on_floor(): return false
	var contact := inside()
	var entered := contact and not was_inside
	was_inside = contact
	if not entered or not State.admits(int(parent.quest_state.shared_flag_38),state()): return false
	# Establish new dialogue state before latching, so migration only affects old saves.
	if not state().has("dialogue"): state().dialogue = State.dialogue_initial()
	state().local24 = 1 # Source group4354 sets this before the two target100 commands.
	if is_instance_valid(parent.village_dialogue): parent.village_dialogue.begin()
	return true

func _physics_process(delta: float) -> void:
	check_contact()
	advance(delta)

func advance(delta: float) -> void:
	if not available or get_tree().paused: return
	# Village alarm g27172 sends movables78/79 to target0: the leaves swing shut (the alarm owner persists it).
	if alarm_closed(): advance_toward(0.0,delta);return
	if state().local24 == 0: return
	advance_toward(State.DURATION,delta)

func alarm_closed() -> bool:
	var alarm = get_parent().get("village_alarm")
	return alarm != null and is_instance_valid(alarm) and alarm.has_method("movable_target") and alarm.movable_target(78) == 0

func advance_toward(destination: float, delta: float) -> void:
	if not available or get_tree().paused: return
	var elapsed := move_toward(float(state().elapsed),destination,maxf(delta,0))
	var target := int(round(elapsed/State.DURATION*100.0))
	# Check both leaves before committing a pose. Adjacent-pose hulls are a
	# conservative modern blocker, not a claim of original crushing/pushing.
	var direction := 1 if target >= pose else -1
	for next in range(pose+direction,target+direction,direction):
		prepare_pose(next)
		for i in leaves.size():
			var hull := ConvexPolygonShape3D.new()
			var points: PackedVector3Array = shapes[pose][i].points
			points.append_array(shapes[next][i].points)
			hull.points = points
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = hull
			query.collision_mask = get_parent().player.collision_layer
			query.transform = global_transform
			for hit in get_world_3d().direct_space_state.intersect_shape(query):
				if hit.collider == get_parent().player: return
		set_pose(next)
		state().elapsed = float(next)/100.0*State.DURATION
	state().elapsed = elapsed
