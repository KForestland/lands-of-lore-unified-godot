extends "res://scripts/lol2/indexed_cave_wall_review.gd"

const SURFACE_ROOT := "res://assets/lol2/generated/surface_indices/"
var indexed_floor_groups := 0

func _indexed_material(path: String) -> ShaderMaterial:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_error("Missing surface indices: " + path)
		get_tree().quit(1)
		return null
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/indexed_surface_review.gdshader")
	material.set_shader_parameter("indices", ImageTexture.create_from_image(image))
	return material

func _ready() -> void:
	super._ready()
	get_window().title = "Indexed cavern — static surfaces · B props · C roof · N/P checkpoints"
	var floor_by_material: Dictionary = {}
	for key in material_cache:
		if not data.materials.has(key):
			var unknown := _indexed_material(INDEX_ROOT + "material_134.png")
			unknown.set_shader_parameter("unresolved", true)
			floor_by_material[material_cache[key].get_instance_id()] = unknown
			continue
		floor_by_material[material_cache[key].get_instance_id()] = _indexed_material(SURFACE_ROOT + "floor_%s.png" % key)
	for child in stage.get_children():
		if child is MeshInstance3D and child != roof:
			var mat: Material = child.mesh.surface_get_material(0)
			if mat != null and floor_by_material.has(mat.get_instance_id()):
				child.material_override = floor_by_material[mat.get_instance_id()]
				child.layers = 2
				indexed_floor_groups += 1
	roof.material_override = _indexed_material(INDEX_ROOT + "material_134.png")
	roof.material_override.set_shader_parameter("roof_tint", true)
	roof.layers = 2
	var props = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/prop_review/props.json")).props
	if props.size() != props_root.get_child_count():
		push_error("Prop instances and source catalogue differ")
		get_tree().quit(1)
		return
	var cache: Dictionary = {}
	for i in range(props.size()):
		var prop: Dictionary = props[i]
		var flags := int(prop.frame_flags) & 0xC0
		var key := "%d:%d" % [int(prop.descriptor), flags]
		if not cache.has(key):
			var material := _indexed_material(SURFACE_ROOT + "prop_%d.png" % int(prop.descriptor))
			material.set_shader_parameter("sprite", true)
			material.set_shader_parameter("uv_scale", Vector2(-1.0 if flags & 0x40 else 1.0, -1.0 if flags & 0x80 else 1.0))
			material.set_shader_parameter("uv_offset", Vector2(1.0 if flags & 0x40 else 0.0, 1.0 if flags & 0x80 else 0.0))
			cache[key] = material
		var instance: MeshInstance3D = props_root.get_child(i)
		instance.material_override = cache[key]
		instance.layers = 2
	resolve_surface.material.set_shader_parameter("apply_roof_tint", true)
	print("Complete indexed static cave: %d floor groups, %d ceilings, %d props" % [indexed_floor_groups, ceiling_count, prop_count])
