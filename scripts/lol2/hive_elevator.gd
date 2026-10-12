extends Node3D
## Source lift surfaces and switch assemblies, adapted to Godot physics.
const State = preload("res://scripts/lol2/hive_elevator_state.gd")
const ROOT := "res://assets/lol2/generated/hive_elevator/"
var checkpoint := State.initial()
var host: Node3D
var data: Dictionary
var platform: StaticBody3D
var controls: Dictionary = {}
var materials: Dictionary = {}
var previous_trigger := -1
var shown_stop := -1
func _ready() -> void:
	host = get_parent()
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"elevator.json"))
	platform = StaticBody3D.new()
	platform.name = "LiftFloor"
	add_child(platform)
	var vertices := PackedVector3Array()
	for face in data.floors:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(host.materials[face.material])
		for index in [0,1,2,0,2,3]:
			var p: Array = face.points[index]
			var vertex := Vector3(p[0],p[1],p[2])
			surface.set_uv(Vector2(face.uv[index][0],face.uv[index][1]))
			surface.add_vertex(vertex)
			vertices.append(vertex)
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		platform.add_child(mesh)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(vertices)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	platform.add_child(collider)
	for record in data.controls:
		var node := Node3D.new()
		(platform if int(record.index)==125 else self).add_child(node)
		var parts: Array = []
		for face in record.faces:
			if not materials.has(face.material):
				var material := StandardMaterial3D.new()
				material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT+face.material))
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				materials[face.material] = material
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(materials[face.material])
			for index in [0,1,2,0,2,3]:
				var p: Array = face.points[index]
				surface.set_uv(Vector2(face.uv[index][0],face.uv[index][1]))
				surface.add_vertex(Vector3(p[0],p[1],p[2]))
			surface.generate_normals()
			var mesh := MeshInstance3D.new()
			mesh.mesh = surface.commit()
			node.add_child(mesh)
			parts.append({"mesh":mesh,"mask":int(face.child_mask)})
		controls[int(record.index)] = {"node":node,"parts":parts,"source":record}
	restore(checkpoint)
func restore(value: Dictionary) -> void:
	assert(State.validate(value).is_empty())
	checkpoint = value.duplicate(true)
	for key in ["target","flute_signal"]: checkpoint[key] = int(checkpoint[key])
	for key in ["height","poll_elapsed"]: checkpoint[key] = float(checkpoint[key])
	platform.position.y = float(checkpoint.height)+235.0
	previous_trigger = trigger_at_player()
	shown_stop = -1
	show_stop()
func trigger_at_player() -> int:
	var position: Vector3 = host.player.position
	for key in data.triggers:
		var row: Dictionary = data.triggers[key]
		if absf(position.y-32.0-float(row.floor)) > 48.0: continue
		var polygon := PackedVector2Array()
		for p in row.polygon: polygon.append(Vector2(p[0],p[1]))
		if Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),polygon): return int(key)
	return -1
func _physics_process(delta: float) -> void:
	if get_tree().paused or host.flying or host.get_node("Warriors").health == 0: return
	var actor = host.get_node("ConversationReview")
	if actor.started and not actor.completed: return
	var region := trigger_at_player()
	if region != previous_trigger and region >= 0: State.enter_trigger(checkpoint,region)
	previous_trigger = region
	var old_height: float = checkpoint.height
	State.advance(checkpoint,delta)
	platform.position.y = float(checkpoint.height)+235.0
	# Transport the standing player by the actual floor displacement. No teleport
	# to a stop; airborne/outside players are excluded and motion stays continuous.
	var rise: float = checkpoint.height-old_height
	if rise != 0 and standing_on_floor(old_height):
		host.player.position.y += rise
	show_stop()
func standing_on_floor(height: float) -> bool:
	if not host.player.is_on_floor(): return false
	if absf(host.player.position.y-32.0-height) > 0.5 or host.player.velocity.y > 0: return false
	var point := Vector2(host.player.position.x,host.player.position.z)
	for face in data.floors:
		var polygon := PackedVector2Array()
		for p in face.points: polygon.append(Vector2(p[0],p[2]))
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false
func show_stop() -> void:
	if shown_stop == int(checkpoint.target): return
	shown_stop = int(checkpoint.target)
	for index in controls:
		var state := shown_stop if int(index)==125 else 0
		for part in controls[index].parts: part.mesh.visible = (part.mask & (1 << state)) != 0
func aim_point(index: int) -> Vector3:
	var point: Array = controls[index].source.position
	return Vector3(point[0],point[1]+32.0+(float(checkpoint.height)+235.0 if index==125 else 0.0),point[2])
func target_control() -> int:
	if host.flying or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or host.interface_hud.cursor_active: return -1
	if host.get_node("Warriors").health == 0: return -1
	var best := -1
	var reach := 96.0
	for index in controls:
		var point := aim_point(index)
		var offset: Vector3 = point-host.camera.global_position
		if offset.length() < 0.01 or offset.length() > reach: continue
		if (-host.camera.global_basis.z).dot(offset.normalized()) < 0.97: continue
		var query := PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
		query.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		best = index
		reach = offset.length()
	return best
func interact() -> bool:
	var index := target_control()
	if index < 0: return false
	checkpoint.target = (int(checkpoint.target)+1)%8 if index==125 else (7 if index==126 else index-126)
	show_stop()
	return true
func play_flute() -> bool:
	if preload("res://scripts/lol2/monastery_conversation.gd").FLUTE not in host.carried_inventory.collected: return false
	return State.play_flute(checkpoint)
