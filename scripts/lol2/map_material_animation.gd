extends Node
## Source frame order with explicitly supplied review timing. Stored resources
## keep exported maps animated without loading the development JSON files.
## Flip bits and frame insets are applied with the texture; timing stays provisional.
@export var sequences: Array[Dictionary] = []

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	for sequence in sequences:
		var frames: Array = sequence.get("frames", [])
		var material = sequence.get("material")
		if frames.is_empty() or material == null: continue
		var fps := float(sequence.get("fps", 1.0))
		if not is_finite(fps) or fps <= 0.0: continue
		var duration := float(frames.size()) / fps
		var elapsed := fmod(float(sequence.get("elapsed", 0.0)) + delta, duration)
		sequence["elapsed"] = elapsed
		var index := mini(int(floor(elapsed * fps)), frames.size() - 1)
		if material is StandardMaterial3D:
			material.albedo_texture = frames[index]
		elif material is ShaderMaterial:
			material.set_shader_parameter("indices", frames[index])
		present(sequence, index)

static func present(sequence: Dictionary, index: int) -> void:
	var material = sequence.get("material")
	var flags: Array = sequence.get("frame_flags", [])
	if material != null and index >= 0 and index < flags.size():
		apply_uv(material, int(flags[index]))
	var hexes: Array = sequence.get("frame_hexes", [])
	if index < 0 or index >= hexes.size(): return
	var raw: PackedByteArray = str(hexes[index]).hex_decode()
	if raw.size() < 9: return
	var half_width := float(sequence.get("half_width", 0.0))
	var quads: Array = sequence.get("quads", [])
	var heights: Array = sequence.get("height_bytes", [])
	for i in quads.size():
		var mesh = quads[i]
		if not mesh is QuadMesh: continue
		var height_byte := float(heights[i]) if i < heights.size() else float(heights[0]) if not heights.is_empty() else 0.0
		apply_bounds(mesh, raw, half_width, height_byte)

static func apply_uv(material, flags: int) -> void:
	var flip_x := (flags & 0x40) != 0
	var flip_y := (flags & 0x80) != 0
	var scale := Vector2(-1.0 if flip_x else 1.0, -1.0 if flip_y else 1.0)
	var offset := Vector2(1.0 if flip_x else 0.0, 1.0 if flip_y else 0.0)
	if material is StandardMaterial3D:
		material.uv1_scale = Vector3(scale.x, scale.y, 1.0)
		material.uv1_offset = Vector3(offset.x, offset.y, 0.0)
	elif material is ShaderMaterial:
		material.set_shader_parameter("uv_scale", scale)
		material.set_shader_parameter("uv_offset", offset)

static func apply_bounds(mesh: QuadMesh, raw: PackedByteArray, half_width: float, height_byte: float) -> void:
	var left := -half_width + float(raw[5])
	var right := half_width - float(raw[7])
	var bottom := float(raw[8])
	var top := height_byte - float(raw[6])
	if right <= left or top <= bottom: return
	mesh.size = Vector2(right - left, top - bottom)
	mesh.center_offset = Vector3((left + right) * 0.5, (bottom + top) * 0.5, 0.0)
