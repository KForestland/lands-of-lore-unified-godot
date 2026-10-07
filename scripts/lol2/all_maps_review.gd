extends Node3D
## Standalone map browser / flythrough. Reads meshes and textures from an
## external JSON export (see docs contract); no game/combat/quest dependency.

const DEFAULT_MAP_ROOT := "/home/bob/lol2_out/all_maps_20260922"
const MISSING_COLOR := Color(1.0, 0.0, 0.8)
const MIN_TRIANGLE_AREA := 1e-6
const FLY_SPEED := 320.0
const FLY_SPEED_FAST := 960.0
const MOUSE_SENSITIVITY := 0.0032

var map_root := DEFAULT_MAP_ROOT
var index_data: Dictionary = {}
var areas: Array = []
var current_area: Dictionary = {}
var current_area_dir := ""
var current_area_index := -1

var geometry_root: Node3D
var props_root: Node3D
var camera_root: Node3D
var camera: Camera3D
var map_environment: WorldEnvironment

var hud: Label
var map_option: OptionButton
var arrival_option: OptionButton
var light_button: Button
var component_option: OptionButton

var material_cache: Dictionary = {}
var prop_material_cache: Dictionary = {}
var texture_info_cache: Dictionary = {}
var animation_states: Array = []
var cutout_ids: Dictionary = {}
var missing_material_ids: Dictionary = {}
var broken_material_paths: Dictionary = {}
var face_counts_by_material: Dictionary = {}
var missing_material_faces := 0
var broken_material_faces := 0
var missing_prop_material_ids: Dictionary = {}
var face_count := 0
var skipped_triangles := 0
var prop_count := 0
var arrivals: Array = []
var component_groups: Array = []
var geometry_document: Dictionary = {}
var start_position := Vector3.ZERO
var bounds_min := Vector3.ZERO
var bounds_max := Vector3.ZERO
var has_bounds := false

var smoke_mode := false
var capture_path := ""
var capture_overhead := false
var capture_frames := 0
var visibility_controller: Node
var sector_mask: ImageTexture
var prop_sector := -1
var light_controller: Node
var light_shade_texture: Texture2D
var light_palette_texture: Texture2D
var prop_light := Vector4(63, 9999, 9999, 128)
var sky_principal_override := Vector2(-1, -1)
var retired_skies: Array[Dictionary] = []

func _ready() -> void:
	# A caller (e.g. the headless smoke test) may assign map_root directly
	# before adding this node to the tree; cmdline args only fill the default.
	if map_root == DEFAULT_MAP_ROOT:
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--map-root="): map_root = argument.trim_prefix("--map-root=")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
		elif argument == "--capture-overhead": capture_overhead = true
	if not capture_path.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Screenshot capture requires a rendering display; omit --headless")
		get_tree().quit(2)
		return
	smoke_mode = "--all-maps-smoke" in OS.get_cmdline_user_args()
	var environment := WorldEnvironment.new()
	map_environment = environment
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.05, 0.06, 0.08)
	add_child(environment)
	geometry_root = Node3D.new()
	add_child(geometry_root)
	props_root = Node3D.new()
	add_child(props_root)
	camera_root = Node3D.new()
	add_child(camera_root)
	camera = Camera3D.new()
	camera.near = 0.5
	camera.far = 60000.0
	camera_root.add_child(camera)
	camera.current = true
	light_controller = preload("res://scripts/lol2/map_light_controller.gd").new()
	add_child(light_controller)
	_build_hud()
	_load_index()
	if "--export-scenes" in OS.get_cmdline_user_args():
		var ok := _run_scene_export("--export-collision" in OS.get_cmdline_user_args())
		get_tree().quit(0 if ok else 1)
		return
	var requested_area := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--area="): requested_area = argument.trim_prefix("--area=")
	if not areas.is_empty():
		var start_index := 0
		if not requested_area.is_empty():
			for i in range(areas.size()):
				if str(areas[i].get("id", "")) == requested_area: start_index = i
		_select_area(start_index)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--component="):
			var component_index := int(argument.trim_prefix("--component="))
			_jump_to_component(component_index)
			if component_option != null and component_index >= 0 and component_index < component_option.item_count:
				component_option.select(component_index)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--arrival="):
			var arrival_index := int(argument.trim_prefix("--arrival="))
			_jump_to_arrival(arrival_index)
			if arrival_index >= 0 and arrival_index < arrival_option.item_count:
				arrival_option.select(arrival_index)
		elif argument.begins_with("--focus-prop="):
			_focus_prop(int(argument.trim_prefix("--focus-prop=")))
	if not capture_path.is_empty() and capture_overhead: _overhead_view()
	set_process(true)
	set_process_unhandled_input(true)

func _focus_prop(record: int) -> void:
	for prop in current_area.get("props", []):
		if int(prop.get("record", -1)) != record: continue
		if str(prop.get("material", "")).begins_with("attached_"): continue
		var point: Array = prop.get("position", [0, 0, 0])
		var height := float(prop.get("top", 0)) - float(prop.get("bottom", 0))
		var width := float(prop.get("right", 0)) - float(prop.get("left", 0))
		var target := Vector3(float(point[0]), float(point[1]), float(point[2]))
		target += Vector3((float(prop.get("left", 0)) + float(prop.get("right", 0))) * 0.5,
			(float(prop.get("bottom", 0)) + float(prop.get("top", 0))) * 0.5, 0)
		camera_root.position = target + Vector3(0, 0, maxf(width, height) * 1.2 + 16.0)
		camera_root.rotation = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		return
	push_warning("No visible scenery placement with record %d" % record)

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var panel := VBoxContainer.new()
	panel.position = Vector2(12, 10)
	ui.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	map_option = OptionButton.new()
	map_option.custom_minimum_size.x = 220
	map_option.item_selected.connect(func(index: int) -> void: _select_area(index))
	row.add_child(map_option)
	arrival_option = OptionButton.new()
	arrival_option.custom_minimum_size.x = 180
	arrival_option.item_selected.connect(func(index: int) -> void: _jump_to_arrival(index))
	row.add_child(arrival_option)
	component_option = OptionButton.new()
	component_option.custom_minimum_size.x = 220
	component_option.item_selected.connect(func(index: int) -> void: _jump_to_component(index))
	row.add_child(component_option)
	light_button = Button.new()
	light_button.text = "Light: off (L)"
	light_button.pressed.connect(func() -> void: light_controller.enabled = not light_controller.enabled)
	row.add_child(light_button)
	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(func() -> void: _reset_camera())
	row.add_child(reset_button)
	var overhead_button := Button.new()
	overhead_button.text = "Overhead"
	overhead_button.pressed.connect(func() -> void: _overhead_view())
	row.add_child(overhead_button)
	hud = Label.new()
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(hud)

func _load_index() -> void:
	var index_path := map_root.path_join("index.json")
	if not FileAccess.file_exists(index_path):
		push_warning("All-maps review: no index at " + index_path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("areas"):
		push_warning("All-maps review: malformed index at " + index_path)
		return
	index_data = parsed
	areas = parsed.areas
	map_option.clear()
	for entry in areas:
		map_option.add_item(str(entry.get("name", entry.get("id", "?"))))

func _load_area_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Area review file missing: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Area review file invalid JSON: " + path)
		return {}
	return parsed

func _select_area(index: int) -> void:
	if index < 0 or index >= areas.size(): return
	var entry: Dictionary = areas[index]
	var review_path := map_root.path_join(str(entry.get("review_file", "")))
	var area_data := _load_area_json(review_path)
	var area_dir := review_path.get_base_dir()
	var failure := "area review file missing or invalid JSON: " + review_path
	if not area_data.is_empty(): failure = _validate_area(area_data, entry, area_dir)
	if not failure.is_empty():
		push_error("All-maps review: " + failure)
		current_area = {}
		current_area_dir = ""
		current_area_index = -1
		_clear_area()
		_reset_counters()
		return
	current_area = area_data
	current_area_dir = area_dir
	current_area_index = index
	_configure_environment()
	_configure_lighting()
	_configure_sector_visibility()
	_clear_area()
	_reset_counters()
	for id in current_area.get("alpha_cutout_materials", []): cutout_ids[str(id)] = true
	_build_faces()
	_build_props()
	for id in missing_material_ids.keys():
		missing_material_faces += int(face_counts_by_material.get(id, 0))
	for id in broken_material_paths.keys():
		broken_material_faces += int(face_counts_by_material.get(id, 0))
	_compute_bounds()
	_populate_arrivals()
	_populate_components()
	var start_array: Array = current_area.get("start", [0, 0, 0])
	start_position = Vector3(float(start_array[0]), float(start_array[1]), float(start_array[2]))
	_reset_camera()
	if map_option != null: map_option.select(index)

func _configure_environment() -> void:
	var environment := map_environment.environment
	environment.background_mode = Environment.BG_COLOR
	_retire_sky(environment.sky)
	environment.sky = null
	var panorama_value = current_area.get("environment", {}).get("panorama")
	if typeof(panorama_value) != TYPE_DICTIONARY: return
	var panorama: Dictionary = panorama_value
	var image := Image.load_from_file(current_area_dir.path_join(str(panorama.get("image", ""))))
	if image == null or image.is_empty(): return
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/lol2/all_maps_sky.gdshader")
	material.set_shader_parameter("panorama", ImageTexture.create_from_image(image))
	var index_path := current_area_dir.path_join(str(panorama.get("indices", "")))
	if FileAccess.file_exists(index_path):
		var indices := Image.load_from_file(index_path)
		if indices != null and not indices.is_empty():
			material.set_shader_parameter("panorama_indices", ImageTexture.create_from_image(indices))
	material.set_shader_parameter("image_aspect", float(panorama.width) / float(panorama.height))
	material.set_shader_parameter("native_projection", panorama.has("vertical_origin"))
	material.set_shader_parameter("vertical_origin", float(panorama.get("vertical_origin", 0)))
	sky.sky_material = material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY

func _configure_lighting() -> void:
	light_controller.materials.clear()
	light_shade_texture = null
	light_palette_texture = null
	var lighting: Dictionary = current_area.get("lighting", {})
	if lighting.is_empty(): return
	light_shade_texture = _load_texture(current_area_dir.path_join(str(lighting.shade_image)))
	light_palette_texture = _load_texture(current_area_dir.path_join(str(lighting.palette_image)))

func _configure_sector_visibility() -> void:
	if visibility_controller != null:
		remove_child(visibility_controller)
		visibility_controller.queue_free()
	visibility_controller = null
	sector_mask = null
	var contract: Dictionary = current_area.get("sector_visibility", {})
	if contract.is_empty(): return
	var source_sectors: Array = contract.get("potential_sectors", [])
	if source_sectors.is_empty(): return
	var image := Image.create(source_sectors.size(), 1, false, Image.FORMAT_R8)
	image.fill(Color.WHITE)
	sector_mask = ImageTexture.create_from_image(image)
	visibility_controller = preload("res://scripts/lol2/map_sector_visibility.gd").new()
	visibility_controller.regions.assign(contract.regions)
	visibility_controller.potential_sectors = source_sectors
	visibility_controller.mask = sector_mask
	visibility_controller.camera_override = camera
	add_child(visibility_controller)

func _bind_light(material: ShaderMaterial, prop: bool) -> void:
	material.set_shader_parameter("sector_visibility", sector_mask != null)
	material.set_shader_parameter("sector_mask", sector_mask)
	material.set_shader_parameter("render_sector", float(prop_sector))
	material.set_shader_parameter("source_lighting", light_shade_texture != null)
	material.set_shader_parameter("shade_table", light_shade_texture)
	material.set_shader_parameter("use_vertex_light", not prop)
	material.set_shader_parameter("sector_light", prop_light)
	material.set_shader_parameter("magic_light", light_controller.enabled if light_controller != null else false)
	if light_controller != null: light_controller.materials.append(material)

func _new_lit_material(id: String, prop: bool, billboard: bool, flags: int) -> Material:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/lol2/all_maps_lit_surface.gdshader")
	material.set_shader_parameter("palette", light_palette_texture)
	material.set_shader_parameter("sprite", billboard)
	material.set_shader_parameter("cutout", cutout_ids.has(id))
	material.set_shader_parameter("front_faces_only", id in current_area.get("front_face_materials", []))
	_bind_light(material, prop)
	preload("res://scripts/lol2/map_material_animation.gd").apply_uv(material, flags)
	var animation: Dictionary = current_area.get("animations", {}).get(id, {})
	var paths: Array = animation.get("index_frames", [])
	if paths.is_empty():
		var entry = current_area.get("indexed_materials", {}).get(id, "")
		paths = [entry.get("image", "") if entry is Dictionary else str(entry)]
	var frames: Array[Texture2D] = []
	for path in paths:
		var texture := _load_texture(current_area_dir.path_join(str(path)))
		if texture != null: frames.append(texture)
		else: broken_material_paths[id] = str(path)
	if not frames.is_empty(): material.set_shader_parameter("indices", frames[0])
	if frames.size() > 1:
		animation_states.append({"material": material, "frames": frames, "fps": maxf(0.01, float(animation.get("fps", 1.0))),
			"elapsed": 0.0, "index": 0, "quads": [], "height_bytes": [], "frame_hexes": [], "frame_flags": [], "half_width": 0.0})
	return material

func _retire_sky(sky: Sky) -> void:
	if sky != null:
		# GLES3 can still have a newly created Sky in its dirty queue. Keep it
		# alive across renderer updates when maps switch within the same frame.
		retired_skies.append({"sky": sky, "frame": Engine.get_process_frames()})

## Rejects the area before anything is built, so a bad map never leaves
## stale geometry from a previously loaded area on screen.
func _validate_area(area_data: Dictionary, entry: Dictionary, area_dir: String) -> String:
	var declared_id := str(entry.get("id", ""))
	var actual_id := str(area_data.get("id", declared_id))
	if not declared_id.is_empty() and not actual_id.is_empty() and declared_id != actual_id:
		return "area id mismatch: index declares '%s' but review file reports '%s'" % [declared_id, actual_id]
	var faces: Array = area_data.get("faces", [])
	if faces.is_empty():
		return "area has no source faces"
	if not _finite_number_array(area_data.get("start", [0, 0, 0])):
		return "start position is not finite"
	for face in faces:
		for p in face.get("points", []):
			if not _finite_number_array(p): return "nonfinite face point"
		for uv in face.get("uv", []):
			if not _finite_number_array(uv): return "nonfinite face uv"
	for prop in area_data.get("props", []):
		if not _finite_number_array(prop.get("position", [0, 0, 0])): return "nonfinite prop position"
	for arrival in area_data.get("arrivals", []):
		if not _finite_number_array(arrival.get("position", [0, 0, 0])): return "nonfinite arrival position"
	var lighting: Dictionary = area_data.get("lighting", {})
	for field in ["shade_image", "palette_image"]:
		if lighting.has(field) and not FileAccess.file_exists(area_dir.path_join(str(lighting[field]))):
			return "declared lighting texture missing: " + str(lighting[field])
	var materials: Dictionary = area_data.get("materials", {})
	for id in materials.keys():
		var path: String = area_dir.path_join(str(materials[id]))
		if not FileAccess.file_exists(path): return "declared material file missing: " + path
	var animations: Dictionary = area_data.get("animations", {})
	for id in animations.keys():
		var animation: Dictionary = animations[id]
		for frame_path in animation.get("frames", []):
			var path: String = area_dir.path_join(str(frame_path))
			if not FileAccess.file_exists(path): return "declared animation frame missing: " + path
	return ""

func _finite_number_array(values) -> bool:
	if typeof(values) != TYPE_ARRAY: return false
	for v in values:
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT: return false
		if not is_finite(float(v)): return false
	return true

func _reset_counters() -> void:
	material_cache.clear()
	prop_material_cache.clear()
	texture_info_cache.clear()
	animation_states.clear()
	cutout_ids.clear()
	missing_material_ids.clear()
	broken_material_paths.clear()
	face_counts_by_material.clear()
	missing_material_faces = 0
	broken_material_faces = 0
	missing_prop_material_ids.clear()
	face_count = 0
	skipped_triangles = 0
	prop_count = 0
	arrivals = []
	component_groups = []
	geometry_document = {}
	bounds_min = Vector3.ZERO
	bounds_max = Vector3.ZERO
	has_bounds = false
	if arrival_option != null: arrival_option.clear()
	_disable_component_chooser()

func _clear_area() -> void:
	for child in geometry_root.get_children():
		geometry_root.remove_child(child)
		child.queue_free()
	for child in props_root.get_children():
		props_root.remove_child(child)
		child.queue_free()

func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): return null
	return ImageTexture.create_from_image(image)

func _new_base_material(id: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_BACK if id in current_area.get("front_face_materials", []) else BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if cutout_ids.has(id):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	return material

## Resolves a material id to its texture(s) once per area. Distinguishes an
## id that is simply not declared anywhere (an expected export gap, reported
## but not fatal) from one that is declared but whose file failed to load
## (a broken export, which the smoke test treats as a failure).
func _resolve_texture_info(id: String) -> Dictionary:
	if texture_info_cache.has(id): return texture_info_cache[id]
	var info := {"texture": null, "frames": [], "fps": 1.0}
	var animations: Dictionary = current_area.get("animations", {})
	if animations.has(id):
		var animation: Dictionary = animations[id]
		var textures: Array[Texture2D] = []
		for frame_path in animation.get("frames", []):
			var path: String = current_area_dir.path_join(str(frame_path))
			var texture := _load_texture(path)
			if texture != null: textures.append(texture)
			else: broken_material_paths[id] = path
		if not textures.is_empty():
			info.texture = textures[0]
			info.frames = textures
			info.fps = maxf(0.01, float(animation.get("fps", 1.0)))
		texture_info_cache[id] = info
		return info
	var materials: Dictionary = current_area.get("materials", {})
	if materials.has(id):
		var path: String = current_area_dir.path_join(str(materials[id]))
		var texture := _load_texture(path)
		if texture != null: info.texture = texture
		else: broken_material_paths[id] = path
	else:
		missing_material_ids[id] = true
	texture_info_cache[id] = info
	return info

func _get_material(id: String) -> Material:
	if material_cache.has(id): return material_cache[id]
	if light_shade_texture != null and current_area.get("indexed_materials", {}).has(id):
		var lit := _new_lit_material(id, false, false, 0)
		material_cache[id] = lit
		return lit
	var info := _resolve_texture_info(id)
	var material := _new_base_material(id)
	if info.texture != null:
		material.albedo_texture = info.texture
	else:
		material.albedo_color = MISSING_COLOR
	if not info.frames.is_empty():
		animation_states.append({"material": material, "frames": info.frames,
			"fps": info.fps, "elapsed": 0.0, "index": 0})
	material_cache[id] = material
	return material

## Props keep a separate material cache from wall/floor geometry so that
## billboard mode never leaks onto shared static surfaces.
func _get_prop_material(id: String, billboard: bool, frame_flags: int = 0) -> Material:
	var key := "%s:%s:%d:%s:%d" % [id, billboard, frame_flags & 0xc0, prop_light, prop_sector]
	if prop_material_cache.has(key): return prop_material_cache[key]
	var material := _new_prop_material(id, billboard, frame_flags)
	prop_material_cache[key] = material
	return material

## Animated placements keep a key that includes the whole flag/inset sequence.
## A static prop with the same first flags must not share that material.
func _material_for_prop(id: String, billboard: bool, frame_flags: int, prop: Dictionary, varied: bool) -> Material:
	if not varied:
		return _get_prop_material(id, billboard, frame_flags)
	var key := "anim:%s:%s:%s:%s:%d" % [id, billboard, _prop_sequence_key(prop), prop_light, prop_sector]
	if prop_material_cache.has(key): return prop_material_cache[key]
	var material := _new_prop_material(id, billboard, frame_flags)
	prop_material_cache[key] = material
	return material

func _new_prop_material(id: String, billboard: bool, frame_flags: int) -> Material:
	if light_shade_texture != null and current_area.get("indexed_materials", {}).has(id):
		return _new_lit_material(id, true, billboard, frame_flags)
	var info := _resolve_texture_info(id)
	var material := _new_base_material(id)
	if billboard: material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_apply_standard_uv(material, frame_flags)
	if info.texture != null:
		material.albedo_texture = info.texture
	else:
		material.albedo_color = MISSING_COLOR
	if not info.frames.is_empty():
		animation_states.append({"material": material, "frames": info.frames,
			"fps": info.fps, "elapsed": 0.0, "index": 0, "quads": [], "height_bytes": [],
			"frame_hexes": [], "frame_flags": [], "half_width": 0.0})
	return material

func _apply_standard_uv(material: StandardMaterial3D, frame_flags: int) -> void:
	material.uv1_scale = Vector3(-1.0 if frame_flags & 0x40 else 1.0, -1.0 if frame_flags & 0x80 else 1.0, 1.0)
	material.uv1_offset = Vector3(1.0 if frame_flags & 0x40 else 0.0, 1.0 if frame_flags & 0x80 else 0.0, 0.0)

func _prop_frame_varies(prop: Dictionary) -> bool:
	var hexes: Array = prop.get("frame_hexes", [])
	var flags: Array = prop.get("frame_flags_list", [])
	if hexes.size() > 1:
		for hex in hexes:
			if str(hex) != str(hexes[0]): return true
	if flags.size() > 1:
		for flag in flags:
			if int(flag) != int(flags[0]): return true
	return false

func _prop_sequence_key(prop: Dictionary) -> String:
	var flag_text := ""
	for flag in prop.get("frame_flags_list", []):
		flag_text += "%d," % int(flag)
	var hex_text := ""
	for hex in prop.get("frame_hexes", []):
		hex_text += str(hex) + ","
	return str(_state_half_width(prop)) + "|" + flag_text + "|" + hex_text

func _state_half_width(prop: Dictionary) -> float:
	var state := str(prop.get("state_hex", "")).hex_decode()
	if state.size() > 14:
		return float(state[14]) * 0.5
	return 0.0

func _placement_height_byte(prop: Dictionary) -> float:
	var hexes: Array = prop.get("frame_hexes", [])
	var first := str(hexes[0] if not hexes.is_empty() else prop.get("frame_hex", "")).hex_decode()
	var trim := float(first[6]) if first.size() > 6 else 0.0
	return float(prop.get("top", 0.0)) + trim

func _attach_prop_frames(material: Material, prop: Dictionary, quad: QuadMesh) -> void:
	for state in animation_states:
		if state.material != material: continue
		if (state.frame_hexes as Array).is_empty():
			state.frame_hexes = prop.get("frame_hexes", []).duplicate()
			state.frame_flags = prop.get("frame_flags_list", []).duplicate()
			state.half_width = _state_half_width(prop)
		(state.quads as Array).append(quad)
		(state.height_bytes as Array).append(_placement_height_byte(prop))
		return

func _build_faces() -> void:
	var groups: Dictionary = {}
	var group_materials: Dictionary = {}
	var movable_groups: Dictionary = {}
	var hidden_groups: Dictionary = {}
	var group_triangle_totals: Dictionary = {}
	var group_face_meta: Dictionary = {}
	face_count = 0
	skipped_triangles = 0
	var all_faces: Array = current_area.get("faces", []).duplicate()
	all_faces.append_array(current_area.get("movable_state_faces", []))
	for face in all_faces:
		var points: Array = face.get("points", [])
		if points.size() < 3: continue
		var uv_source: Array = face.get("uv", [])
		var material_id := str(face.get("material", ""))
		var group_id := material_id
		if str(face.get("kind", "")) == "emulated_boundary":
			group_id = "EmulatedBoundary_Material_%s" % material_id
		if str(face.get("kind", "")) == "movable":
			group_id = "Movable_%s_%s_Material_%s" % [face.get("placement", -1), face.get("child", -1), material_id]
			movable_groups[group_id] = {"placement": face.get("placement"), "child": face.get("child"), "template": face.get("template"), "child_mask": face.get("child_mask", 1)}
			if not bool(face.get("initial_visible", true)):
				hidden_groups[group_id] = true
		group_materials[group_id] = material_id
		var vertices: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for i in range(points.size()):
			var p: Array = points[i]
			vertices.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
			if i < uv_source.size():
				var uv: Array = uv_source[i]
				uvs.append(Vector2(float(uv[0]), float(uv[1])))
			else:
				uvs.append(Vector2.ZERO)
		if not groups.has(group_id):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
			surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
			groups[group_id] = surface
		var surface: SurfaceTool = groups[group_id]
		var light: Array = face.get("sector_light", [63, 9999, 9999, 128])
		surface.set_custom(0, Color(float(light[0]), float(light[1]), float(light[2]), float(light[3])))
		surface.set_custom(1, Color(float(face.get("render_sector", -1)), 0, 0, 0))
		var used := false
		for i in range(1, vertices.size() - 1):
			var a := vertices[0]
			var b := vertices[i]
			var c := vertices[i + 1]
			if (b - a).cross(c - a).length() < MIN_TRIANGLE_AREA:
				skipped_triangles += 1
				continue
			surface.set_uv(uvs[0]); surface.add_vertex(a)
			surface.set_uv(uvs[i]); surface.add_vertex(b)
			surface.set_uv(uvs[i + 1]); surface.add_vertex(c)
			used = true
			group_triangle_totals[group_id] = int(group_triangle_totals.get(group_id, 0)) + 1
		if used:
			if not hidden_groups.has(group_id): face_count += 1
			face_counts_by_material[material_id] = int(face_counts_by_material.get(material_id, 0)) + 1
			var meta_list: Array = group_face_meta.get(group_id, [])
			var source_meta: Dictionary = face.duplicate(true)
			source_meta.erase("points")
			source_meta.erase("uv")
			meta_list.append(source_meta)
			group_face_meta[group_id] = meta_list
	for group_id in groups.keys():
		var material_id: String = group_materials[group_id]
		if int(group_triangle_totals.get(group_id, 0)) == 0: continue
		var surface: SurfaceTool = groups[group_id]
		surface.generate_normals()
		var mesh := surface.commit()
		if mesh.get_surface_count() == 0: continue
		mesh.surface_set_material(0, _get_material(material_id))
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.name = group_id if movable_groups.has(group_id) or group_id.begins_with("EmulatedBoundary_") else "Material_%s" % material_id
		if group_id.begins_with("EmulatedBoundary_"):
			instance.set_meta("emulated_boundary", true)
			instance.set_meta("native_verified", false)
		instance.visible = not hidden_groups.has(group_id)
		if movable_groups.has(group_id): instance.set_meta("movable", movable_groups[group_id])
		# Aggregate mesh: retains the ordered region/face ids that were
		# merged into it so later gameplay code can still identify objects.
		instance.set_meta("material_id", material_id)
		instance.set_meta("region_faces", group_face_meta.get(group_id, []))
		geometry_root.add_child(instance)

## Billboarding and yaw are review conventions for browsing these classic
## sprite-style props, not a claim of recovered original placement behavior.
func _build_props() -> void:
	prop_count = 0
	var all_props: Array = current_area.get("props", []).duplicate()
	all_props.append_array(current_area.get("attached_state_props", []))
	for prop in all_props:
		var width := float(prop.get("width", 0.0))
		var height := float(prop.get("height", 0.0))
		# Descriptor dimensions are pixels; frame bounds are world dimensions.
		if prop.has("left") and prop.has("right"):
			width = float(prop.right) - float(prop.left)
		if prop.has("bottom") and prop.has("top"):
			height = float(prop.top) - float(prop.bottom)
		if width <= 0.0 or height <= 0.0: continue
		var material_id := str(prop.get("material", ""))
		var billboard: bool = bool(prop.get("billboard", true))
		var frame_bytes := str(prop.get("frame_hex", "")).hex_decode()
		var frame_flags := int(frame_bytes[2]) if frame_bytes.size() > 2 else 0
		var varied := _prop_frame_varies(prop)
		var light: Array = prop.get("sector_light", [63, 9999, 9999, 128])
		prop_light = Vector4(float(light[0]), float(light[1]), float(light[2]), float(light[3]))
		prop_sector = int(prop.get("render_sector", -1))
		var material := _material_for_prop(material_id, billboard, frame_flags, prop, varied)
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		# Preserve the source sprite anchor when left/right/bottom/top are
		# supplied; otherwise default to a base-anchored quad above position.
		var offset := Vector3(0, height * 0.5, 0)
		if prop.has("left") and prop.has("right"):
			offset.x = (float(prop.left) + float(prop.right)) * 0.5
		if prop.has("bottom") and prop.has("top"):
			offset.y = (float(prop.bottom) + float(prop.top)) * 0.5
		quad.center_offset = offset
		quad.material = material
		if varied: _attach_prop_frames(material, prop, quad)
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		var position_array: Array = prop.get("position", [0, 0, 0])
		instance.position = Vector3(float(position_array[0]), float(position_array[1]), float(position_array[2]))
		if not billboard and prop.has("yaw"): instance.rotation.y = float(prop.yaw)
		instance.set_meta("source", prop.duplicate(true))
		instance.visible = not bool(prop.get("hidden", false))
		props_root.add_child(instance)
		if instance.visible: prop_count += 1
		if missing_material_ids.has(material_id) or broken_material_paths.has(material_id):
			missing_prop_material_ids[material_id] = true

## --export-scenes: builds each valid area exactly like the interactive
## viewer, then saves its static geometry/props (no HUD/camera/controller)
## as a standalone .scn for later gameplay code to build on. A map that
## fails validation, produces no geometry, or fails to save counts as a
## command failure; a map with only unresolved (undeclared) material ids
## still gets exported, flagged not-ready via its embedded source summary.
func _run_scene_export(export_collision: bool) -> bool:
	if areas.is_empty():
		push_error("All-maps review: no areas in index to export")
		return false
	var report: Array = []
	var overall_ok := true
	for i in range(areas.size()):
		var entry: Dictionary = areas[i]
		var area_id := str(entry.get("id", "area_%d" % i))
		var row := {
			"id": area_id, "name": str(entry.get("name", area_id)),
			"attempted": true, "success": false, "path": "",
			"mesh_count": 0, "prop_count": 0, "face_count": 0, "skipped_triangles": 0,
			"unresolved_materials": 0, "unresolved_material_faces": 0,
			"unresolved_prop_materials": 0, "ready": false, "error": ""}
		_select_area(i)
		if current_area.is_empty():
			row.error = "area failed to load or failed validation (see preceding error)"
			overall_ok = false
			report.append(row)
			continue
		if geometry_root.get_child_count() == 0:
			row.error = "area produced no geometry"
			overall_ok = false
			report.append(row)
			continue
		var ready: bool = bool(current_area.get("summary", {}).get("ready_for_content", false)) \
			and missing_material_ids.is_empty() and missing_prop_material_ids.is_empty() \
			and current_area.get("geometry_issues", []).is_empty() \
			and current_area.get("prop_issues", []).is_empty() \
			and current_area.get("attached_prop_issues", []).is_empty() \
			and current_area.get("attached_state_issues", []).is_empty() \
			and current_area.get("movable_issues", []).is_empty() \
			and current_area.get("movable_state_issues", []).is_empty() \
			and current_area.get("material_issues", []).is_empty()
		row.mesh_count = geometry_root.get_child_count()
		row.prop_count = props_root.get_child_count()
		row.face_count = face_count
		row.skipped_triangles = skipped_triangles
		row.unresolved_materials = missing_material_ids.size()
		row.unresolved_material_faces = missing_material_faces
		row.unresolved_prop_materials = missing_prop_material_ids.size()
		row.ready = ready
		var area_dir := map_root.path_join(area_id)
		DirAccess.make_dir_recursive_absolute(area_dir)
		var scene_path := area_dir.path_join("map.scn")
		var save_error := _save_area_scene(scene_path, area_id, entry, export_collision, ready)
		if save_error != OK:
			row.error = "scene save failed: error %d" % save_error
			overall_ok = false
		else:
			row.success = true
			row.path = scene_path
		report.append(row)
	var report_path := map_root.path_join("scene_export_report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("All-maps review: could not write export report to " + report_path)
		return false
	file.store_string(JSON.stringify({"map_root": map_root, "areas": report}, "  "))
	file.close()
	print("All-maps review: export report written to " + report_path)
	return overall_ok

## Packs only the built geometry/props (never the HUD/camera/controller)
## under a fresh root, embeds provenance metadata, then saves. The live
## geometry_root/props_root nodes are reparented for the pack and restored
## afterward with owners cleared, rather than duplicated, so metadata set
## during _build_faces/_build_props (which Node.duplicate() does not
## reliably carry) survives into the saved scene.
func _save_area_scene(scene_path: String, area_id: String, entry: Dictionary, export_collision: bool, ready: bool) -> Error:
	remove_child(geometry_root)
	remove_child(props_root)
	var export_root := Node3D.new()
	export_root.name = "Area"
	geometry_root.name = "Geometry"
	props_root.name = "Props"
	export_root.add_child(geometry_root)
	export_root.add_child(props_root)
	var exported_environment := WorldEnvironment.new()
	exported_environment.name = "Environment"
	exported_environment.environment = map_environment.environment.duplicate(true)
	export_root.add_child(exported_environment)
	var sky_controller = preload("res://scripts/lol2/map_sky_controller.gd").new()
	sky_controller.name = "SkyController"
	sky_controller.environment_path = NodePath("../Environment")
	export_root.add_child(sky_controller)
	if visibility_controller != null:
		var saved_visibility = preload("res://scripts/lol2/map_sector_visibility.gd").new()
		saved_visibility.name = "SectorVisibility"
		saved_visibility.regions = visibility_controller.regions
		saved_visibility.potential_sectors = visibility_controller.potential_sectors
		saved_visibility.mask = sector_mask
		export_root.add_child(saved_visibility)
	if not light_controller.materials.is_empty():
		var saved_light = preload("res://scripts/lol2/map_light_controller.gd").new()
		saved_light.name = "MagicLight"
		saved_light.materials.assign(light_controller.materials)
		export_root.add_child(saved_light)
	var video_anchors := Node3D.new()
	video_anchors.name = "VideoPlacements"
	for source in current_area.get("video_placements", []):
		var placement: Dictionary = source.get("comparison", {}).get("placement", {})
		var source_position: Array = placement.get("position", [])
		if source_position.size() != 3: continue
		var anchor := Marker3D.new()
		anchor.name = "Placement_%s" % placement.get("record", video_anchors.get_child_count())
		anchor.position = Vector3(float(source_position[0]), float(source_position[1]), float(source_position[2]))
		anchor.set_meta("source", source)
		anchor.set_meta("visual_binding_pending", true)
		video_anchors.add_child(anchor)
	export_root.add_child(video_anchors)
	var collision: Node3D = null
	if export_collision:
		collision = _build_structural_collision(geometry_root)
		if collision != null: export_root.add_child(collision)
	if not animation_states.is_empty():
		var animator = preload("res://scripts/lol2/map_material_animation.gd").new()
		animator.name = "MaterialAnimations"
		for state in animation_states:
			animator.sequences.append({
				"material": state.material, "frames": state.frames, "fps": state.fps, "elapsed": 0.0,
				"quads": state.get("quads", []), "frame_hexes": state.get("frame_hexes", []),
				"frame_flags": state.get("frame_flags", []), "height_bytes": state.get("height_bytes", []),
				"half_width": state.get("half_width", 0.0)})
		export_root.add_child(animator)
	export_root.set_meta("area_id", area_id)
	export_root.set_meta("source", _build_source_summary(area_id, entry, ready))
	_set_owner_recursive(export_root, export_root)
	var packed := PackedScene.new()
	var error := packed.pack(export_root)
	if error == OK:
		error = ResourceSaver.save(packed, scene_path)
	export_root.remove_child(geometry_root)
	export_root.remove_child(props_root)
	export_root.queue_free()
	_set_owner_recursive(geometry_root, null)
	geometry_root.owner = null
	_set_owner_recursive(props_root, null)
	props_root.owner = null
	add_child(geometry_root)
	add_child(props_root)
	if error != OK:
		push_error("All-maps review: scene save failed for %s to %s (error %d)" % [area_id, scene_path, error])
	return error

func _build_source_summary(area_id: String, entry: Dictionary, ready: bool) -> Dictionary:
	return {
		"area_id": area_id,
		"name": str(entry.get("name", area_id)),
		"review_file": map_root.path_join(str(entry.get("review_file", ""))),
		"generated_at": Time.get_datetime_string_from_system(true),
		"original_source": current_area.get("source", {}),
		"captured_surface_state": current_area.get("captured_surface_state", {}),
		"coverage": current_area.get("summary", {}),
		"prop_issues": current_area.get("prop_issues", []),
		"attached_prop_issues": current_area.get("attached_prop_issues", []),
		"attached_state_issues": current_area.get("attached_state_issues", []),
		"movable_issues": current_area.get("movable_issues", []),
		"movable_state_issues": current_area.get("movable_state_issues", []),
		"movable_placements": current_area.get("movable_placements", []),
		"geometry_issues": current_area.get("geometry_issues", []),
		"sector_admission": current_area.get("sector_admission", {}),
		"material_issues": current_area.get("material_issues", []),
		"environment": current_area.get("environment", {}),
		"lighting": current_area.get("lighting", {}),
		"video_placements": current_area.get("video_placements", []),
		"movable_source_templates": current_area.get("movable_source_templates", []),
		"movable_inactive_children": current_area.get("movable_inactive_children", []),
		"attached_inactive_children": current_area.get("attached_inactive_children", []),
		"nonvisual_props": current_area.get("nonvisual_props", []),
		"attached_nonvisual_props": current_area.get("attached_nonvisual_props", []),
		"face_count": face_count,
		"skipped_triangles": skipped_triangles,
		"unresolved_materials": missing_material_ids.keys(),
		"unresolved_material_faces": missing_material_faces,
		"unresolved_prop_materials": missing_prop_material_ids.keys(),
		"prop_count": props_root.get_child_count(),
		"issues": current_area.get("issues", []),
		"ready": ready,
	}

## Convenience trimesh from structural (wall/floor/ceiling) geometry only;
## props are skipped. This is a review-time collision approximation for
## later gameplay code to start from, not a recovery of original collision.
func _build_structural_collision(geometry: Node3D) -> Node3D:
	var faces := PackedVector3Array()
	if current_area.has("structural_visibility"):
		# Keep original material-group and triangle order independently of render
		# fronts. Winding changes can perturb physics on very thin faraway faces.
		var groups: Dictionary = {}
		for face in current_area.get("faces", []):
			if str(face.get("kind", "")) == "movable": continue
			var group_id := str(face.get("visibility_original_material", face.get("material", "")))
			if str(face.get("kind", "")) == "emulated_boundary":
				group_id = "EmulatedBoundary_Material_%s" % group_id
			if not groups.has(group_id): groups[group_id] = PackedVector3Array()
			var points: Array = face.get("points", []).duplicate()
			if bool(face.get("source_winding_reversed", false)) and points.size() > 1:
				var tail := points.slice(1)
				tail.reverse()
				points = [points[0]] + tail
			if points.size() < 3: continue
			var a := Vector3(float(points[0][0]), float(points[0][1]), float(points[0][2]))
			var triangles: PackedVector3Array = groups[group_id]
			for i in range(1, points.size() - 1):
				var b := Vector3(float(points[i][0]), float(points[i][1]), float(points[i][2]))
				var c := Vector3(float(points[i+1][0]), float(points[i+1][1]), float(points[i+1][2]))
				if (b-a).cross(c-a).length() < MIN_TRIANGLE_AREA: continue
				triangles.append_array(PackedVector3Array([a, b, c]))
			groups[group_id] = triangles
		for triangles in groups.values(): faces.append_array(triangles)
	for child in geometry.get_children():
		if current_area.has("structural_visibility"): break
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null: continue
		if mesh_instance.has_meta("movable"): continue
		var mesh: Mesh = mesh_instance.mesh
		for surface_index in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index_variant = arrays[Mesh.ARRAY_INDEX]
			if index_variant == null or (index_variant as PackedInt32Array).is_empty():
				for v in vertices: faces.append(mesh_instance.transform * v)
			else:
				var indices: PackedInt32Array = index_variant
				for idx in indices: faces.append(mesh_instance.transform * vertices[idx])
	if faces.is_empty(): return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = "StructuralCollision"
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return body

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)

func _compute_bounds() -> void:
	has_bounds = false
	bounds_min = Vector3.ZERO
	bounds_max = Vector3.ZERO
	for face in current_area.get("faces", []):
		for p in face.get("points", []):
			var v := Vector3(float(p[0]), float(p[1]), float(p[2]))
			if not has_bounds:
				bounds_min = v
				bounds_max = v
				has_bounds = true
			else:
				bounds_min = Vector3(minf(bounds_min.x, v.x), minf(bounds_min.y, v.y), minf(bounds_min.z, v.z))
				bounds_max = Vector3(maxf(bounds_max.x, v.x), maxf(bounds_max.y, v.y), maxf(bounds_max.z, v.z))

func _populate_arrivals() -> void:
	arrivals = current_area.get("arrivals", [])
	if arrival_option != null:
		arrival_option.clear()
		for i in range(arrivals.size()):
			arrival_option.add_item("Arrival %d" % (i + 1))

func _disable_component_chooser() -> void:
	if component_option == null: return
	component_option.set_block_signals(true)
	component_option.clear()
	component_option.disabled = true
	component_option.set_block_signals(false)

## Topology groups from review_inventory.json. A missing inventory, a source
## SHA that does not match the loaded area, or a malformed document leaves
## the chooser disabled. Readiness and geometry files are not written.
func _populate_components() -> void:
	component_groups = []
	_disable_component_chooser()
	if current_area_dir.is_empty(): return
	var inventory_path := current_area_dir.path_join("review_inventory.json")
	if not FileAccess.file_exists(inventory_path): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(inventory_path))
	if typeof(parsed) != TYPE_DICTIONARY: return
	var inventory: Dictionary = parsed
	if str(inventory.get("schema", "")) != "lol2-map-review-inventory-v1": return
	var inventory_sha := str(inventory.get("source", {}).get("sha256", ""))
	var area_sha := str(current_area.get("source", {}).get("sha256", ""))
	if inventory_sha.is_empty() or area_sha.is_empty() or inventory_sha != area_sha:
		push_warning("All-maps review: component inventory source does not match the loaded area")
		return
	var listed: Array = inventory.get("topology", {}).get("components", [])
	if listed.is_empty(): return
	component_groups = listed
	if component_option == null: return
	component_option.set_block_signals(true)
	component_option.clear()
	for i in range(component_groups.size()):
		var group: Dictionary = component_groups[i]
		var count := int(group.get("region_count", (group.get("region_ids", []) as Array).size()))
		component_option.add_item("Group%d (%d regions)" % [i + 1, count])
	component_option.disabled = false
	component_option.set_block_signals(false)

## Preview only. An arrival already listed for the group is used as-is.
## Otherwise the camera sits at the source-quad centroid of the roomiest
## primary region, at mid floor/ceiling. That point is not a gameplay spawn.
func _jump_to_component(index: int) -> void:
	if index < 0 or index >= component_groups.size(): return
	var group: Dictionary = component_groups[index]
	var arrival_index := _arrival_index_for_group(group)
	if arrival_index >= 0:
		_jump_to_arrival(arrival_index)
		if arrival_option != null and arrival_index < arrival_option.item_count:
			arrival_option.select(arrival_index)
		return
	var preview = _component_region_preview(group)
	if preview == null: return
	camera_root.position = preview
	camera_root.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO

func _arrival_index_for_group(group: Dictionary) -> int:
	var wanted: Array = group.get("arrival_ids", [])
	if wanted.is_empty(): return -1
	var wanted_index = wanted[0]
	for i in range(arrivals.size()):
		var arrival: Dictionary = arrivals[i]
		if arrival.has("index") and int(arrival.get("index")) == int(wanted_index):
			return i
		if not arrival.has("index") and i == int(wanted_index):
			return i
	return -1

func _load_geometry_document() -> Dictionary:
	if not geometry_document.is_empty(): return geometry_document
	var path := current_area_dir.path_join("geometry/geometry.json")
	if not FileAccess.file_exists(path):
		push_warning("All-maps review: no geometry for component preview at " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("All-maps review: geometry JSON is not an object at " + path)
		return {}
	if str(parsed.get("source", {}).get("sha256", "")) != str(current_area.get("source", {}).get("sha256", "")):
		push_warning("All-maps review: component geometry source does not match the loaded area")
		return {}
	geometry_document = parsed
	return geometry_document

## Largest nondegenerate horizontal footprint among primary_region members
## with ceiling above floor. World x = fixed_x/65536, z = -fixed_y/65536.
## Child roles are not candidates even if a group lists them.
func _component_region_preview(group: Dictionary):
	var geometry := _load_geometry_document()
	if geometry.is_empty(): return null
	var by_id := {}
	for record in geometry.get("regions", []):
		if typeof(record) != TYPE_DICTIONARY: continue
		by_id[int(record.get("id", -1))] = record
	var vertices: Array = geometry.get("vertices_fixed", [])
	var best_area := 0.0
	var best: Vector3
	var found := false
	for region_id in group.get("region_ids", []):
		var record: Dictionary = by_id.get(int(region_id), {})
		if record.is_empty(): continue
		if str(record.get("record_role", "")) != "primary_region": continue
		var source_bytes := str(record.get("raw_hex", "")).hex_decode()
		if source_bytes.size() == 44 and source_bytes[32] == 255 and record.get("floor_subdivisions", []).is_empty():
			# Spatial helper volumes can have valid bounds but explicitly no
			# floor surface. They are not useful standing preview positions.
			continue
		var floor_height := -INF
		var ceiling_height := INF
		for value in record.get("floor_corners", []):
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT: continue
			floor_height = maxf(floor_height, float(value))
		for value in record.get("ceiling_corners", []):
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT: continue
			ceiling_height = minf(ceiling_height, float(value))
		if not is_finite(floor_height) or not is_finite(ceiling_height) or ceiling_height <= floor_height: continue
		var polygon: PackedVector2Array = PackedVector2Array()
		var finite := true
		for vertex_index in record.get("vertex_indices", []):
			if typeof(vertex_index) != TYPE_INT and typeof(vertex_index) != TYPE_FLOAT:
				finite = false
				break
			var index := int(vertex_index)
			if index < 0 or index >= vertices.size():
				finite = false
				break
			var pair = vertices[index]
			if typeof(pair) != TYPE_ARRAY or pair.size() < 2: 
				finite = false
				break
			if not _finite_number_array([pair[0], pair[1]]):
				finite = false
				break
			polygon.append(Vector2(float(pair[0]) / 65536.0, -float(pair[1]) / 65536.0))
		if not finite or polygon.size() < 3: continue
		var area := _horizontal_polygon_area(polygon)
		if area <= 1e-8 or area <= best_area: continue
		var centroid := Vector2.ZERO
		for point in polygon:
			centroid += point
		centroid /= float(polygon.size())
		best_area = area
		best = Vector3(centroid.x, (floor_height + ceiling_height) * 0.5, centroid.y)
		found = true
	if not found: return null
	return best

func _horizontal_polygon_area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	var count := polygon.size()
	for i in range(count):
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5

func _jump_to_arrival(index: int) -> void:
	if index < 0 or index >= arrivals.size(): return
	var arrival: Dictionary = arrivals[index]
	var position_array: Array = arrival.get("position", [0, 0, 0])
	camera_root.position = Vector3(float(position_array[0]), float(position_array[1]), float(position_array[2]))
	# Native bearing111C34 is atan2(dx, dy); map Y becomes Godot -Z.
	camera_root.rotation = Vector3(0.0, -float(arrival.get("heading", 0)) * TAU / 65536.0, 0.0)
	camera.rotation = Vector3.ZERO

func _reset_camera() -> void:
	camera_root.position = start_position
	camera_root.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	if not arrivals.is_empty(): _jump_to_arrival(0)

func _overhead_view() -> void:
	if not has_bounds: return
	var center := (bounds_min + bounds_max) * 0.5
	var span := maxf(bounds_max.x - bounds_min.x, bounds_max.z - bounds_min.z)
	camera_root.position = Vector3(center.x, bounds_max.y + span * 0.75 + 200.0, center.z)
	camera_root.rotation = Vector3.ZERO
	camera.rotation = Vector3(-PI / 2.0, 0, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_root.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_R:
			_reset_camera()
		elif event.keycode == KEY_O:
			_overhead_view()

func _process(delta: float) -> void:
	for i in range(retired_skies.size()-1, -1, -1):
		if Engine.get_process_frames()-int(retired_skies[i].frame) >= 2:
			retired_skies.remove_at(i)
	_advance_animations(delta)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var input_direction := Vector3(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0,
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		var vertical := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		var speed := FLY_SPEED_FAST if Input.is_physical_key_pressed(KEY_SHIFT) else FLY_SPEED
		var direction := camera.global_basis * input_direction
		direction.y += vertical
		if direction.length_squared() > 0.0:
			camera_root.position += direction.normalized() * speed * delta
	preload("res://scripts/lol2/map_sky_controller.gd").update_sky(map_environment.environment, camera, sky_principal_override)
	_update_hud()
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 3: _capture_screenshot()

func _capture_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var directory := capture_path.get_base_dir()
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	if error != OK:
		push_error("All-maps review: screenshot failed to save to " + capture_path)
		get_tree().quit(1)
		return
	print("All-maps review: screenshot saved to " + capture_path)
	get_tree().quit(0)

func _advance_animations(delta: float) -> void:
	var presenter = preload("res://scripts/lol2/map_material_animation.gd")
	for state in animation_states:
		state.previous = int(state.index)
		state.elapsed += delta
		var frame_duration: float = 1.0 / state.fps
		var frames: Array = state.frames
		while state.elapsed >= frame_duration and frames.size() > 1:
			state.elapsed -= frame_duration
			state.index = (state.index + 1) % frames.size()
		if state.material is StandardMaterial3D and not frames.is_empty():
			state.material.albedo_texture = frames[int(state.index)]
		elif state.material is ShaderMaterial and not frames.is_empty():
			state.material.set_shader_parameter("indices", frames[int(state.index)])
		presenter.present(state, int(state.index))

func _update_hud() -> void:
	if light_button != null: light_button.text = "Light: %s (L)" % ("on" if light_controller.enabled else "off")
	if hud == null: return
	var name := str(current_area.get("name", current_area.get("id", "(no map loaded)")))
	var issue_count := 0
	for field in ["issues", "geometry_issues", "prop_issues", "attached_prop_issues", "movable_issues", "material_issues"]:
		issue_count += current_area.get(field, []).size()
	hud.text = "All-maps review · %s\nfaces %d · skipped triangles %d · unresolved materials (gap) %d (%d faces) · broken declared materials %d (%d faces) · props %d (%d unresolved)\nWASD move · mouse look · Q/E vertical · Shift speed · Esc release · click capture · R reset · O overhead · L magical light%s\n%s" % [
		name, face_count, skipped_triangles, missing_material_ids.size(), missing_material_faces,
		broken_material_paths.size(), broken_material_faces,
		prop_count, missing_prop_material_ids.size(),
		"\nReview in progress: %d geometry / scenery / material issues" % issue_count,
		str(camera_root.position)]
