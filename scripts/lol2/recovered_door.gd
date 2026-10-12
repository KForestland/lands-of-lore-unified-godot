extends Node3D
## Source geometry and sampled native hinge path, relative to placement anchor.
## This visual component intentionally has no collision or automatic event rules.
signal opening_changed(percent: int)
var original_record := -1
var opening_percent := -1
var _frames: Array = []
var _surfaces: Array[MeshInstance3D] = []
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _unit_scale := 1.0

func configure(record: Dictionary, unit_scale: float = 1.0) -> void:
	assert(unit_scale > 0.0)
	assert(record.frames.size() == 101)
	original_record = int(record.index)
	set_meta("original_record", original_record)
	_frames = record.frames
	_unit_scale = unit_scale
	_meshes.clear()
	for surface in _surfaces:
		remove_child(surface)
		surface.queue_free()
	_surfaces.clear()
	for id in [470, 85]:
		var material := StandardMaterial3D.new()
		# Raw PNG (kept unimported in exports), like the other recovered materials.
		material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/doors/material_%d.png" % id))
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[id] = material
	for face in range(4):
		var surface := MeshInstance3D.new()
		add_child(surface)
		_surfaces.append(surface)
	opening_percent = -1
	set_opening(0)

func set_opening(percent: int) -> void:
	assert(not _frames.is_empty(), "Configure recovered door before setting opening")
	var frame := clampi(percent, 0, 100)
	if frame == opening_percent:
		return
	if not _meshes.has(frame):
		var meshes: Array[ArrayMesh] = []
		for face in _frames[frame]:
			var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			if int(face.face) == 3:
				uv = [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(_materials[int(face.material)])
			for vertex in [0, 1, 2, 0, 2, 3]:
				builder.set_uv(uv[vertex])
				var p: Array = face.vertices[vertex]
				builder.add_vertex(Vector3(p[0], p[1], p[2]) * _unit_scale)
			meshes.append(builder.commit())
		_meshes[frame] = meshes
	for i in range(4):
		_surfaces[i].mesh = _meshes[frame][i]
	opening_percent = frame
	opening_changed.emit(frame)

func pose_points(percent: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for face in _frames[clampi(percent, 0, 100)]:
		for vertex in [0, 1, 2, 0, 2, 3]:
			var p: Array = face.vertices[vertex]
			points.append(Vector3(p[0], p[1], p[2]) * _unit_scale)
	return points
