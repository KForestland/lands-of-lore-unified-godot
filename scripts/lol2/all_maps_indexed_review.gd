extends "res://scripts/lol2/all_maps_review.gd"
## Optional indexed review. Layer-1 meshes stay visible to every index camera.
## cull_mask 1|(source_id<<1) is read back as CAMERA_VISIBLE_LAYERS, and the
## surface shader shifts that mask to select the pass in the same frame.

const INDEXED_SURFACE := preload("res://scripts/lol2/all_maps_indexed_surface.gdshader")
const REMAP_LAYER := preload("res://scripts/lol2/indexed_remap_layer.gdshader")
const PALETTE_RESOLVE := preload("res://scripts/lol2/indexed_wall_resolve.gdshader")

var quit_if_unindexed := true
var contract_error := ""
var primed_contract: Dictionary = {}
var primed_dir := ""
var shader_materials: Array[ShaderMaterial] = []
var next_source_id := 1
var palette_texture: Texture2D
var remap_texture: Texture2D
var base_view: SubViewport
var base_camera: Camera3D
var source_views: Dictionary = {}
var composite_views: Array[SubViewport] = []
var resolve_layer: CanvasLayer
var resolve_rect: ColorRect
var resolve_material: ShaderMaterial
var visible_ids: Array[int] = []
var shadow_pass_cache: Dictionary = {}
var layers_clean := false
var indexed_frames := 0
var pipeline_ready := false
var benchmark_frames := 0
var benchmark_quit := true
var benchmark_samples: Array[float] = []
var benchmark_pass_counts: Array[int] = []
var benchmark_report: Dictionary = {}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-frames="):
			benchmark_frames = maxi(int(argument.trim_prefix("--benchmark-frames=")), 0)
	super._ready()
	_build_pipeline()
	camera.current = false
	_apply_indexed_sky()
	pipeline_ready = true

func _reset_counters() -> void:
	super._reset_counters()
	shader_materials.clear()
	shadow_pass_cache.clear()
	next_source_id = 1
	visible_ids.clear()
	layers_clean = false

func _select_area(index: int) -> void:
	_release_source_views()
	_prime_contract(index)
	super._select_area(index)
	if current_area.is_empty():
		return
	_assign_layers(geometry_root)
	_assign_layers(props_root)
	if not contract_error.is_empty():
		push_error("Indexed all-maps review: " + contract_error)
		if quit_if_unindexed:
			get_tree().quit(1)
		return
	_bind_palette_and_remap()
	_apply_indexed_sky()
	layers_clean = false

func _prime_contract(index: int) -> void:
	contract_error = ""
	primed_contract = {}
	primed_dir = ""
	if index < 0 or index >= areas.size():
		return
	var entry: Dictionary = areas[index]
	var review_path := map_root.path_join(str(entry.get("review_file", "")))
	var area_data := _load_area_json(review_path)
	if area_data.is_empty():
		return
	primed_dir = review_path.get_base_dir()
	primed_contract = _merge_indexed_contract(area_data, primed_dir, index_data)
	contract_error = str(primed_contract.get("error", ""))

## Area JSON wins over materials.json. Index-level sprite_initial_remap fills
## a gap until a root binder writes it onto the area. palette.png and
## indices/<id>.png are direct-path fallbacks.
func _merge_indexed_contract(area_data: Dictionary, area_dir: String, root_index: Dictionary) -> Dictionary:
	var merged := {"indexed_materials": {}, "shadow_masks": {}, "palette": "", "remap_hex": "", "remap_image": ""}
	var sidecar := area_dir.path_join("materials.json")
	if FileAccess.file_exists(sidecar):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(sidecar))
		if typeof(parsed) == TYPE_DICTIONARY:
			_overlay_contract(merged, parsed)
	_overlay_contract(merged, area_data)
	if str(merged.remap_hex).is_empty() and root_index.has("sprite_initial_remap"):
		merged.remap_hex = _remap_hex_of(root_index.sprite_initial_remap)
	if str(merged.palette).is_empty() and FileAccess.file_exists(area_dir.path_join("materials/palette_rgb.png")):
		merged.palette = "materials/palette_rgb.png"
	if str(merged.palette).is_empty() and FileAccess.file_exists(area_dir.path_join("palette.png")):
		merged.palette = "palette.png"
	if (merged.indexed_materials as Dictionary).is_empty():
		var direct := DirAccess.open(area_dir.path_join("indices"))
		if direct != null:
			var found := {}
			direct.list_dir_begin()
			var name := direct.get_next()
			while not name.is_empty():
				if name.ends_with(".png"):
					found[name.trim_suffix(".png")] = "indices".path_join(name)
				name = direct.get_next()
			merged.indexed_materials = found
	var error := ""
	if str(merged.palette).is_empty() or not FileAccess.file_exists(area_dir.path_join(str(merged.palette))):
		error = "missing palette PNG (palette_image, materials/palette_rgb.png, or palette.png)"
	elif (merged.indexed_materials as Dictionary).is_empty():
		error = "missing indexed_materials (area JSON, materials.json, or indices/*.png)"
	merged.error = error
	return merged

func _overlay_contract(merged: Dictionary, source: Dictionary) -> void:
	if source.has("indexed_materials") and typeof(source.indexed_materials) == TYPE_DICTIONARY:
		merged.indexed_materials = source.indexed_materials
	if source.has("shadow_masks") and typeof(source.shadow_masks) == TYPE_DICTIONARY:
		merged.shadow_masks = source.shadow_masks
	if source.has("palette_image"):
		merged.palette = str(source.palette_image)
	elif source.has("palette"):
		merged.palette = str(source.palette)
	if source.has("remap_image"):
		merged.remap_image = str(source.remap_image)
	var hex := _remap_hex_of(source.get("sprite_initial_remap", ""))
	if not hex.is_empty():
		merged.remap_hex = hex

func _remap_hex_of(value) -> String:
	if typeof(value) == TYPE_STRING:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("remap_hex", ""))
	return ""

func _contract_path(relative: String) -> String:
	if relative.begins_with("res://") or relative.begins_with("/"):
		return relative
	return primed_dir.path_join(relative)

func _entry_index_path(id: String) -> String:
	var table: Dictionary = primed_contract.get("indexed_materials", {})
	if not table.has(id):
		return ""
	var entry = table[id]
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get("indices", entry.get("path", "")))
	return str(entry)

func _entry_shadow_flag(id: String) -> bool:
	var table: Dictionary = primed_contract.get("indexed_materials", {})
	var entry = table.get(id, null)
	return typeof(entry) == TYPE_DICTIONARY and bool(entry.get("shadow", false))

func _load_index_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return _load_texture(_contract_path(path))

func _image_has_value(path: String, target: int, any_nonzero: bool) -> bool:
	if path.is_empty() or not FileAccess.file_exists(_contract_path(path)):
		return false
	var image := Image.load_from_file(_contract_path(path))
	if image == null or image.is_empty():
		return false
	for y in image.get_height():
		for x in image.get_width():
			var value := image.get_pixel(x, y).r8
			if any_nonzero and value != 0:
				return true
			if not any_nonzero and value == target:
				return true
	return false

func _shadow_mask_path(id: String) -> String:
	var masks: Dictionary = primed_contract.get("shadow_masks", {})
	if masks.has(id):
		return str(masks[id])
	var animations: Dictionary = current_area.get("animations", {}) if not current_area.is_empty() else {}
	if animations.is_empty():
		# During _get_material, current_area is already assigned by the parent
		# before materials are built. Fall through to the primed area file.
		pass
	return ""

## An explicit mask that is all zero means index 1 is an ordinary color
## (block-sprite family). Pixel value 1 is a shadow only when no mask exists.
func _explicit_mask_paths(id: String) -> Array[String]:
	var paths: Array[String] = []
	var masks: Dictionary = primed_contract.get("shadow_masks", {})
	if masks.has(id):
		paths.append(str(masks[id]))
	if not current_area.is_empty():
		var animations: Dictionary = current_area.get("animations", {})
		if animations.has(id):
			for frame_path in animations[id].get("shadow_frames", []):
				paths.append(str(frame_path))
	return paths

func _needs_shadow_pass(id: String) -> bool:
	if shadow_pass_cache.has(id):
		return bool(shadow_pass_cache[id])
	var needed := _classify_shadow_pass(id)
	shadow_pass_cache[id] = needed
	return needed

func _classify_shadow_pass(id: String) -> bool:
	if _entry_shadow_flag(id):
		return true
	var masks := _explicit_mask_paths(id)
	if not masks.is_empty():
		for path in masks:
			if _image_has_value(path, 0, true):
				return true
		return false
	if _image_has_value(_entry_index_path(id), 1, false):
		return true
	if not current_area.is_empty():
		var animations: Dictionary = current_area.get("animations", {})
		if animations.has(id):
			for frame_path in animations[id].get("index_frames", []):
				if _image_has_value(str(frame_path), 1, false):
					return true
	return false

func _index_frames_for(id: String, info: Dictionary) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var animations: Dictionary = current_area.get("animations", {})
	if animations.has(id):
		for frame_path in animations[id].get("index_frames", []):
			var texture := _load_index_texture(str(frame_path))
			if texture == null:
				contract_error = "index frame failed to load for %s: %s" % [id, frame_path]
			else:
				frames.append(texture)
	if frames.is_empty():
		var texture := _load_index_texture(_entry_index_path(id))
		if texture == null:
			contract_error = "missing index PNG for material %s" % id
		else:
			frames.append(texture)
	if info.has("fps"):
		pass
	return frames

func _shadow_frames_for(id: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var animations: Dictionary = current_area.get("animations", {})
	if animations.has(id):
		for frame_path in animations[id].get("shadow_frames", []):
			var texture := _load_index_texture(str(frame_path))
			if texture != null:
				frames.append(texture)
	if frames.is_empty():
		var masks: Dictionary = primed_contract.get("shadow_masks", {})
		if masks.has(id):
			var texture := _load_index_texture(str(masks[id]))
			if texture != null:
				frames.append(texture)
	return frames

func _make_indexed_material(id: String, sprite: bool, frame_flags: int, source_id: int) -> ShaderMaterial:
	var info := _resolve_texture_info(id)
	var frames := _index_frames_for(id, info)
	var shadows := _shadow_frames_for(id)
	var material := ShaderMaterial.new()
	material.shader = INDEXED_SURFACE
	_bind_light(material, false)
	material.set_shader_parameter("front_faces_only", id in current_area.get("front_face_materials", []))
	material.set_shader_parameter("sprite", sprite)
	material.set_shader_parameter("cutout", cutout_ids.has(id))
	material.set_shader_parameter("source_id", source_id)
	material.set_shader_parameter("uv_scale", Vector2(-1.0 if frame_flags & 0x40 else 1.0, -1.0 if frame_flags & 0x80 else 1.0))
	material.set_shader_parameter("uv_offset", Vector2(1.0 if frame_flags & 0x40 else 0.0, 1.0 if frame_flags & 0x80 else 0.0))
	if not frames.is_empty():
		material.set_shader_parameter("indices", frames[0])
	var masked := source_id > 0 and not shadows.is_empty()
	material.set_shader_parameter("has_shadow_mask", masked)
	material.set_shader_parameter("legacy_shadow", source_id > 0 and shadows.is_empty())
	if masked:
		material.set_shader_parameter("shadow_mask", shadows[0])
	var fps := 1.0
	var animations: Dictionary = current_area.get("animations", {})
	if animations.has(id):
		fps = maxf(0.01, float(animations[id].get("fps", info.get("fps", 1.0))))
	if frames.size() > 1 or shadows.size() > 1:
		animation_states.append({
			"material": material, "frames": frames, "shadow_frames": shadows,
			"fps": fps, "elapsed": 0.0, "index": 0, "quads": [], "height_bytes": [],
			"frame_hexes": [], "frame_flags": [], "half_width": 0.0,
		})
	shader_materials.append(material)
	return material

func _get_material(id: String) -> Material:
	var table: Dictionary = primed_contract.get("indexed_materials", {})
	if contract_error.is_empty() and not table.is_empty() and not table.has(id):
		contract_error = "missing index PNG for material %s" % id
	if contract_error.is_empty() and table.has(id):
		if material_cache.has(id):
			return material_cache[id]
		var material := _make_indexed_material(id, false, 0, 0)
		material_cache[id] = material
		return material
	return super._get_material(id)

func _new_prop_material(id: String, billboard: bool, frame_flags: int) -> Material:
	var table: Dictionary = primed_contract.get("indexed_materials", {})
	if not contract_error.is_empty() or not table.has(id):
		return super._new_prop_material(id, billboard, frame_flags)
	var shadow := _needs_shadow_pass(id)
	var source_id := 0
	if shadow:
		source_id = next_source_id
		next_source_id += 1
	var material := _make_indexed_material(id, billboard, frame_flags, source_id)
	material.set_shader_parameter("use_vertex_light", false)
	return material

func _get_prop_material(id: String, billboard: bool, frame_flags: int = 0) -> Material:
	var shadow := contract_error.is_empty() and _needs_shadow_pass(id)
	var table: Dictionary = primed_contract.get("indexed_materials", {})
	if contract_error.is_empty() and not table.is_empty() and not table.has(id):
		contract_error = "missing index PNG for prop %s" % id
	if contract_error.is_empty() and table.has(id):
		var key := "%s:%s:%d:%s:%d" % [id, billboard, frame_flags & 0xc0, prop_light, prop_sector]
		if not shadow and prop_material_cache.has(key):
			return prop_material_cache[key]
		var material := _new_prop_material(id, billboard, frame_flags)
		if not shadow:
			prop_material_cache[key] = material
		return material
	return super._get_prop_material(id, billboard, frame_flags)

func _material_for_prop(id: String, billboard: bool, frame_flags: int, prop: Dictionary, varied: bool) -> Material:
	if varied and contract_error.is_empty() and _needs_shadow_pass(id):
		return _new_prop_material(id, billboard, frame_flags)
	return super._material_for_prop(id, billboard, frame_flags, prop, varied)

func _advance_animations(delta: float) -> void:
	super._advance_animations(delta)
	for state in animation_states:
		var material: Material = state.material
		if not material is ShaderMaterial: continue
		var frames: Array = state.frames
		if not frames.is_empty():
			material.set_shader_parameter("indices", frames[int(state.index) % frames.size()])
		var shadows: Array = state.get("shadow_frames", [])
		if bool(material.get_shader_parameter("has_shadow_mask")) and not shadows.is_empty():
			material.set_shader_parameter("shadow_mask", shadows[int(state.index) % shadows.size()])
		if int(state.index) != int(state.get("previous", state.index)):
			layers_clean = false

func _assign_layers(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			child.layers = 1

func _bind_palette_and_remap() -> void:
	palette_texture = light_palette_texture if light_palette_texture != null else _load_index_texture(str(primed_contract.get("palette", "")))
	var remap_path := str(primed_contract.get("remap_image", ""))
	if not remap_path.is_empty():
		remap_texture = _load_index_texture(remap_path)
		if remap_texture == null:
			contract_error = "remap_image failed to load: " + remap_path
			push_error("Indexed all-maps review: " + contract_error)
			if quit_if_unindexed:
				get_tree().quit(1)
			return
	else:
		var hex := str(primed_contract.get("remap_hex", ""))
		var image := Image.create(256, 1, false, Image.FORMAT_R8)
		if hex.is_empty():
			if next_source_id > 1:
				contract_error = "shadow sprites need sprite_initial_remap or remap_image"
				push_error("Indexed all-maps review: " + contract_error)
				if quit_if_unindexed:
					get_tree().quit(1)
				return
			for i in 256:
				image.set_pixel(i, 0, Color(float(i) / 255.0, 0, 0))
		else:
			var bytes := hex.hex_decode()
			if bytes.size() < 256:
				contract_error = "sprite_initial_remap.remap_hex must contain 256 bytes"
				push_error("Indexed all-maps review: " + contract_error)
				if quit_if_unindexed:
					get_tree().quit(1)
				return
			for i in 256:
				image.set_pixel(i, 0, Color(float(bytes[i]) / 255.0, 0, 0))
		remap_texture = ImageTexture.create_from_image(image)
	if resolve_material != null and palette_texture != null:
		resolve_material.set_shader_parameter("palette", palette_texture)

func _indexed_environment() -> Environment:
	# Clone only the resources we modify. A deep Environment duplicate creates
	# an intermediate Sky that the explicit clone below immediately discards.
	# Godot's GLES3 dirty-sky queue can allocate radiance textures after that
	# temporary Sky has been freed. Sharing the untouched resources avoids it.
	var env := map_environment.environment.duplicate(false) as Environment
	if env.sky != null and env.sky.sky_material is ShaderMaterial:
		var sky := env.sky.duplicate() as Sky
		var material := (env.sky.sky_material as ShaderMaterial).duplicate() as ShaderMaterial
		material.set_shader_parameter("indexed", true)
		sky.sky_material = material
		env.sky = sky
	return env

func _apply_indexed_sky() -> void:
	if base_camera == null or map_environment == null:
		return
	if base_camera.environment != null:
		_retire_sky(base_camera.environment.sky)
	base_camera.environment = _indexed_environment()

func _build_pipeline() -> void:
	var packed_clear := Color(64.0 / 255.0, 64.0 / 255.0, 0.0)
	base_view = _make_world_view(packed_clear)
	base_camera = base_view.get_child(0)
	base_camera.cull_mask = 1
	resolve_layer = CanvasLayer.new()
	resolve_layer.layer = 1
	add_child(resolve_layer)
	resolve_rect = ColorRect.new()
	resolve_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	resolve_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolve_material = ShaderMaterial.new()
	resolve_material.shader = PALETTE_RESOLVE
	resolve_rect.material = resolve_material
	resolve_layer.add_child(resolve_rect)
	if palette_texture != null:
		resolve_material.set_shader_parameter("palette", palette_texture)

func _make_world_view(clear: Color) -> SubViewport:
	var view := SubViewport.new()
	var window_size := get_viewport().get_visible_rect().size
	view.size = Vector2i(maxi(int(window_size.x), 2), maxi(int(window_size.y), 2))
	view.own_world_3d = false
	view.world_3d = get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(view)
	var cam := Camera3D.new()
	cam.cull_mask = 1
	cam.environment = Environment.new()
	cam.environment.background_mode = Environment.BG_COLOR
	cam.environment.background_color = clear
	view.add_child(cam)
	cam.current = true
	return view

func _sync_camera(cam: Camera3D) -> void:
	cam.global_transform = camera.global_transform
	cam.projection = camera.projection
	cam.keep_aspect = camera.keep_aspect
	cam.frustum_offset = camera.frustum_offset
	cam.h_offset = camera.h_offset
	cam.v_offset = camera.v_offset
	cam.fov = camera.fov
	cam.size = camera.size
	cam.near = camera.near
	cam.far = camera.far

func _source_view(source_id: int) -> SubViewport:
	if source_views.has(source_id):
		return source_views[source_id]
	var packed_clear := Color(64.0 / 255.0, 64.0 / 255.0, 0.0)
	var view := _make_world_view(packed_clear)
	view.size = base_view.size
	var cam: Camera3D = view.get_child(0)
	cam.cull_mask = 1 | (source_id << 1)
	source_views[source_id] = view
	return view

func _prop_material(instance: MeshInstance3D) -> ShaderMaterial:
	var material := instance.mesh.surface_get_material(0)
	if material is ShaderMaterial:
		return material
	return null

func _shadow_distance(instance: MeshInstance3D) -> float:
	var forward := -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 1e-8:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var mesh := instance.mesh as QuadMesh
	var center := instance.global_position
	if mesh != null:
		center += camera.global_basis.x * mesh.center_offset.x + Vector3.UP * mesh.center_offset.y
	return center.dot(forward) - camera.global_position.dot(forward)

func _quad_corners(instance: MeshInstance3D) -> Array[Vector3]:
	var mesh := instance.mesh as QuadMesh
	var material := _prop_material(instance)
	var sprite := material != null and bool(material.get_shader_parameter("sprite"))
	var center := instance.global_position
	var axis_x: Vector3
	var axis_y: Vector3
	if sprite:
		axis_x = camera.global_basis.x
		axis_y = Vector3.UP
		center += axis_x * mesh.center_offset.x + axis_y * mesh.center_offset.y
	else:
		center += instance.global_transform.basis * mesh.center_offset
		axis_x = instance.global_transform.basis.x
		axis_y = instance.global_transform.basis.y
	var half_x := axis_x * mesh.size.x * 0.5
	var half_y := axis_y * mesh.size.y * 0.5
	return [center + half_x + half_y, center + half_x - half_y, center - half_x + half_y, center - half_x - half_y]

## Reject only when every corner is outside one frustum plane. A quad that
## crosses the viewport, or surrounds it, stays even if no corner is inside.
func _prop_in_frustum(instance: MeshInstance3D) -> bool:
	if not (instance.mesh is QuadMesh):
		return false
	var corners := _quad_corners(instance)
	for plane in camera.get_frustum():
		var outside := true
		for corner in corners:
			# Frustum planes from Camera3D point outward.
			if plane.distance_to(corner) <= 0.0:
				outside = false
				break
		if outside:
			return false
	return true

func _detach_viewport_textures() -> void:
	if resolve_material != null:
		resolve_material.set_shader_parameter("packed_wall_indices", null)
	for view in composite_views:
		if view.get_child_count() == 0:
			continue
		var material: ShaderMaterial = view.get_child(0).material
		material.set_shader_parameter("background_indices", null)
		material.set_shader_parameter("source_indices", null)

func _release_source_views() -> void:
	_detach_viewport_textures()
	for source_id in source_views.keys():
		var view: SubViewport = source_views[source_id]
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		source_views[source_id] = null
		view.queue_free()
	source_views.clear()
	visible_ids.clear()

func _release_for_shutdown() -> void:
	pipeline_ready = false
	set_process(false)
	_detach_viewport_textures()
	for material in shader_materials:
		material.set_shader_parameter("indices", null)
		material.set_shader_parameter("shadow_mask", null)
	for view in composite_views:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if view.get_child_count() == 0:
			continue
		var composite_material: ShaderMaterial = view.get_child(0).material
		composite_material.set_shader_parameter("remap", null)
	if base_camera != null and base_camera.environment != null:
		base_camera.environment.sky = null
	if map_environment != null and map_environment.environment != null:
		map_environment.environment.sky = null
	if resolve_material != null:
		resolve_material.set_shader_parameter("palette", null)
		resolve_rect.material = null
	_release_source_views()
	for view in composite_views:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		view.queue_free()
	composite_views.clear()
	if base_view != null:
		base_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		base_view.queue_free()
		base_view = null
		base_camera = null
	palette_texture = null
	remap_texture = null

func _exit_tree() -> void:
	_detach_viewport_textures()
	for material in shader_materials:
		material.set_shader_parameter("indices", null)
		material.set_shader_parameter("shadow_mask", null)
	shader_materials.clear()
	for view in composite_views:
		if view.get_child_count() == 0:
			continue
		var material: ShaderMaterial = view.get_child(0).material
		material.set_shader_parameter("remap", null)
	if resolve_material != null:
		resolve_material.set_shader_parameter("palette", null)
	if base_camera != null and base_camera.environment != null:
		base_camera.environment.sky = null
	palette_texture = null
	remap_texture = null
	source_views.clear()

func _refresh_visible_specials() -> void:
	var found: Array[int] = []
	var ranked: Array = []
	for child in props_root.get_children():
		if not (child is MeshInstance3D):
			continue
		if not child.is_visible_in_tree(): continue
		var material := _prop_material(child)
		if material == null:
			continue
		var source_id := int(material.get_shader_parameter("source_id"))
		if source_id <= 0:
			continue
		if not _prop_in_frustum(child):
			continue
		ranked.append({"id": source_id, "distance": _shadow_distance(child)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.distance == b.distance:
			return int(a.id) < int(b.id)
		return float(a.distance) > float(b.distance))
	for row in ranked:
		found.append(int(row.id))
	visible_ids = found

func _ensure_composites(count: int) -> void:
	while composite_views.size() < count:
		var view := SubViewport.new()
		view.size = base_view.size
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(view)
		var surface := ColorRect.new()
		surface.size = Vector2(view.size)
		var material := ShaderMaterial.new()
		material.shader = REMAP_LAYER
		material.set_shader_parameter("remap", remap_texture)
		surface.material = material
		view.add_child(surface)
		composite_views.append(view)
	for i in composite_views.size():
		var view := composite_views[i]
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if i < count else SubViewport.UPDATE_DISABLED

func _rebind_composites() -> void:
	_ensure_composites(visible_ids.size())
	var background: Texture2D = base_view.get_texture()
	for i in visible_ids.size():
		var source_id := visible_ids[i]
		var view := composite_views[i]
		var surface: ColorRect = view.get_child(0)
		var material: ShaderMaterial = surface.material
		material.set_shader_parameter("remap", remap_texture)
		material.set_shader_parameter("background_indices", background)
		material.set_shader_parameter("source_indices", _source_view(source_id).get_texture())
		background = view.get_texture()
	if resolve_material != null:
		resolve_material.set_shader_parameter("packed_wall_indices", background)
		if palette_texture != null:
			resolve_material.set_shader_parameter("palette", palette_texture)

func _resize_views() -> void:
	var window_size := get_viewport().get_visible_rect().size
	var size := Vector2i(maxi(int(window_size.x), 2), maxi(int(window_size.y), 2))
	resolve_rect.position = Vector2.ZERO
	resolve_rect.size = Vector2(size)
	if base_view.size != size:
		base_view.size = size
		for id in source_views.keys():
			var source: SubViewport = source_views[id]
			source.size = size
		for view in composite_views:
			view.size = size
			view.get_child(0).size = Vector2(size)

func _schedule_pass() -> void:
	if contract_error != "" or not pipeline_ready or shader_materials.is_empty():
		return
	_resize_views()
	_sync_camera(base_camera)
	base_camera.cull_mask = 1
	base_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_refresh_visible_specials()
	for source_id in visible_ids:
		_source_view(int(source_id))
	for source_id in source_views.keys():
		var view: SubViewport = source_views[source_id]
		var used := visible_ids.has(int(source_id))
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if used else SubViewport.UPDATE_DISABLED
		if used:
			var cam: Camera3D = view.get_child(0)
			_sync_camera(cam)
			cam.cull_mask = 1 | (int(source_id) << 1)
	_rebind_composites()
	layers_clean = indexed_frames >= 3

func _process(delta: float) -> void:
	var hold := capture_path
	var capture_ready := (benchmark_frames == 0 or not benchmark_report.is_empty()) and indexed_frames >= 20 and layers_clean
	if not capture_ready:
		capture_path = ""
	super._process(delta)
	capture_path = hold
	indexed_frames += 1
	if pipeline_ready:
		_schedule_pass()
		preload("res://scripts/lol2/map_sky_controller.gd").update_sky(base_camera.environment, camera, sky_principal_override)
		_sample_benchmark(delta)

func _sample_benchmark(delta: float) -> void:
	if benchmark_frames <= 0 or not benchmark_report.is_empty():
		return
	if indexed_frames < 20 or not layers_clean:
		return
	camera_root.position += camera.global_basis.x * 80.0 * delta
	var passes := 1 + visible_ids.size() + mini(visible_ids.size(), composite_views.size())
	benchmark_samples.append(delta * 1000.0)
	benchmark_pass_counts.append(passes)
	if benchmark_samples.size() < benchmark_frames:
		return
	var total := 0.0
	var peak := 0.0
	var pass_total := 0
	var pass_peak := 0
	for sample in benchmark_samples:
		total += sample
		peak = maxf(peak, sample)
	for count in benchmark_pass_counts:
		pass_total += count
		pass_peak = maxi(pass_peak, count)
	benchmark_report = {
		"frames": benchmark_samples.size(),
		"avg_ms": total / benchmark_samples.size(),
		"max_ms": peak,
		"avg_passes": float(pass_total) / benchmark_pass_counts.size(),
		"max_passes": pass_peak,
	}
	print("Indexed benchmark: frames %d avg_ms %.2f max_ms %.2f avg_passes %.1f max_passes %d" % [
		benchmark_report.frames, benchmark_report.avg_ms, benchmark_report.max_ms,
		benchmark_report.avg_passes, benchmark_report.max_passes])
	if benchmark_quit:
		_release_for_shutdown()
		await get_tree().process_frame
		get_tree().quit(0)

func _capture_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var directory := capture_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	if error != OK:
		push_error("All-maps review: screenshot failed to save to " + capture_path)
		_release_for_shutdown()
		await get_tree().process_frame
		get_tree().quit(1)
		return
	print("All-maps review: screenshot saved to " + capture_path)
	_release_for_shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
