extends RefCounted
## Native chained descriptors124/125 and upper palette blend table.
## Reference renderer uses unshaded indices; original shade-row selection remains a renderer limitation.
const ROOT := "res://assets/lol2/generated/cave_stalagmite/"
var meshes: Dictionary = {}
var textures: Array[Texture2D] = []
var depth_view: SubViewport
const DEPTH_FLAG := 1 << 14
const COMPARE_FLAG := 1 << 15
const TABLE_SHA := "d4daf38375e2b3ad916893fa72986926d730fe3681bbc7181ca6c63771c615a9"

func setup(host: Node3D, crystals: Node3D, source: Dictionary) -> void:
	for name in ["124.png", "125.png"]:
		textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + name)))
	var table := Image.load_from_file(ROOT + "blend_upper.png")
	if table == null or table.get_size() != Vector2i(256,128):
		push_error("Original crystal blend table missing or invalid")
		return
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(table.get_data())
	if hash.finish().hex_encode() != TABLE_SHA:
		push_error("Original crystal blend table hash mismatch")
		return
	var blend := ImageTexture.create_from_image(table)
	# Reuse the existing live mask meshes. The camera flag selects depth output instead of source0.
	# No extra world copies, no mask reassignment, and no use of the legacy default visual layer.
	depth_view = SubViewport.new()
	depth_view.msaa_3d = Viewport.MSAA_DISABLED
	depth_view.size = host.index_view.size
	depth_view.world_3d = host.get_world_3d()
	depth_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(depth_view)
	var depth_camera := Camera3D.new()
	depth_camera.cull_mask = 4 | DEPTH_FLAG
	depth_camera.fov = host.camera.fov
	depth_camera.near = host.camera.near
	depth_camera.far = host.camera.far
	depth_camera.environment = Environment.new()
	depth_camera.environment.background_mode = Environment.BG_COLOR
	depth_camera.environment.background_color = Color.BLACK
	depth_view.add_child(depth_camera)
	depth_camera.current = true
	depth_camera.global_transform = host.camera.global_transform
	host.layer_cameras.append(depth_camera)
	var previous: Texture2D = host.composites.back().get_texture()
	for i in source.plants.size():
		var plant: Dictionary = source.plants[i]
		var record := int(plant.record)
		var ordinary: MeshInstance3D = crystals.plants[record]
		var mesh := MeshInstance3D.new()
		mesh.mesh = ordinary.mesh
		mesh.layers = 1 << (7 + i)
		var material: ShaderMaterial = ordinary.material_override.duplicate()
		material.set_shader_parameter("indices", textures[0])
		material.set_shader_parameter("crystal_depth", depth_view.get_texture())
		material.set_shader_parameter("compare_crystal_depth", true)
		mesh.material_override = material
		host.add_child(mesh)
		mesh.global_transform = ordinary.global_transform
		meshes[record] = mesh
		host.placed_instances.append(mesh)
		host.placed_props.append({"record": record, "position_native": plant.position, "palette_blend": true})
		var raw: SubViewport = host._source_view(mesh.layers, false)
		raw.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var view: SubViewport = host._source_view(mesh.layers)
		view.get_child(0).cull_mask = mesh.layers | COMPARE_FLAG
		var composite: SubViewport = host._compose(previous, view.get_texture())
		composite.get_child(0).material.set_shader_parameter("palette_blend", true)
		previous = composite.get_texture()
	for composite in host.composites:
		composite.get_child(0).material.set_shader_parameter("blend_table", blend)
	host.resolve_surface.material.set_shader_parameter("packed_wall_indices", previous)

func restore(record: int, collected: bool) -> void:
	if meshes.has(record):
		meshes[record].material_override.set_shader_parameter("indices", textures[1 if collected else 0])

func sync_depth(host: Node3D) -> void:
	if depth_view == null: return
	if depth_view.size != host.index_view.size: depth_view.size = host.index_view.size
	var active := false
	for i in host.placed_props.size():
		if bool(host.placed_props[i].get("palette_blend", false)) and host.layer_views[i].render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			active = true
	depth_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
