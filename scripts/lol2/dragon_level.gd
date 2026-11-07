extends "res://scripts/lol2/jungle_walkthrough.gd"
## L9 native map and shared Act 2 progression binder.
const FORMAT := "lol2-restoration-dragon-preview"
const DEFAULT_PATH := "user://saves/dragon_preview_quicksave.json"
const PACK := "res://assets/lol2/generated/dragon_level/area.json"
const RAY_MASK := 1
var prop_batches := 0
var prop_instances := 0
var prop_placements: Dictionary = {}
var preview_assemblies: Node3D
var preview_blockers := 0
@export var adapter_exit_seeds := true
var progression: Node = null
var act2_items: Node3D
var act2_creatures: Node3D
var start_selector := 0
var arrived_by_level_change := false

static func arrival_assets_ready() -> bool:
	if not FileAccess.file_exists(PACK): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	if not data is Dictionary or not data.get("materials") is Dictionary: return false
	for file in data.materials.values():
		if not FileAccess.file_exists(PACK.get_base_dir()+"/"+file): return false
	return preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready()

func _init() -> void:
	super._init()
	huline_content = false
	geometry_file = PACK
	sky_pack = "res://assets/lol2/generated/dragon_sky/"
	review_title = "Dragon level preview"
	area_name = "Dragon level preview"
	area_save_path = DEFAULT_PATH
	area_save_format = FORMAT
	region_blockers_enabled = true
	# No Jungle-specific fills/clipping; missing-neighbour walls remain OPEN.
	fill_untextured_edges = false
	clip_sunken_groups = false

func include_collision_face(face: Dictionary) -> bool:
	# Floors and ceilings form the terrain shell. Source walls draw only; assembly boxes are separate.
	return face.kind in ["floor", "ceiling"]

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
	var Binder := preload("res://scripts/lol2/act2_progression.gd")
	if Binder.assets_ready("L9_DR"): excluded_faces.merge(Binder.hinge_faces("L9_DR", data))
	for i in data.faces.size():
		if data.faces[i].get("placement_kind")=="static_assembly" and int(data.faces[i].get("source_index",-1)) in [312,478,479,480,122,82]:excluded_faces[i]=true
	super._ready()
	preload("res://scripts/lol2/act2_visuals.gd").apply(self, "L9_DR")
	var prop_materials: Dictionary = {}
	var groups: Dictionary = {}
	for row in data.props.size():
		var prop: Dictionary = data.props[row]
		var flip := int(prop.get("frame_flags", 0)) & 0xC0
		var key := "%s|%s|%s|%s|%s|%d" % [prop.material, prop.left, prop.right, prop.bottom, prop.top, flip]
		if not groups.has(key): groups[key] = []
		# Placement rows carry their record; the 134 attached type-1 children (map_primitive_geometry) carry none and are keyed
		# by their pack row below zero (-1 - row).
		groups[key].append([prop, int(prop.record) if prop.has("record") else -1 - row])
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var rows: Array = groups[key]
		var first: Dictionary = rows[0][0]
		var material_key: String = first.material
		var flip := int(first.get("frame_flags", 0)) & 0xC0
		var material_id := "%s|%d" % [material_key, flip]
		if not prop_materials.has(material_id):
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(geometry_file.get_base_dir()+"/"+data.materials[material_key]))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			# Native 129AC8 frame setup: flag 0x40 reverses the columns, 0x80 the rows (hive_jungle_scenery.gd).
			material.uv1_scale = Vector3(-1.0 if flip & 0x40 else 1.0, -1.0 if flip & 0x80 else 1.0, 1.0)
			material.uv1_offset = Vector3(1.0 if flip & 0x40 else 0.0, 1.0 if flip & 0x80 else 0.0, 0.0)
			prop_materials[material_id] = material
		var quad := QuadMesh.new()
		quad.size = Vector2(float(first.right) - float(first.left), float(first.top) - float(first.bottom))
		quad.center_offset = Vector3((float(first.left) + float(first.right)) / 2.0, (float(first.bottom) + float(first.top)) / 2.0, 0)
		quad.material = prop_materials[material_id]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = quad
		multi.instance_count = rows.size()
		for i in rows.size():
			var prop: Dictionary = rows[i][0]
			var at := Vector3(prop.position[0], prop.position[1], prop.position[2])
			multi.set_instance_transform(i, Transform3D(Basis(), at))
			prop_placements[int(rows[i][1])] = [multi, i, at]
		var node := MultiMeshInstance3D.new()
		node.name = "DragonProps_%d" % prop_batches
		node.multimesh = multi
		add_child(node)
		prop_batches += 1
		prop_instances += rows.size()
	# Selector0 is the native preview arrival; its campaign-route label remains unbound.
	# Heading is an adapter until native units and camera conversion are bound.
	player.rotation.y = 0.0
	if preload("res://scripts/lol2/static_assemblies.gd").assets_ready("L9_DR"):
		preview_assemblies = preload("res://scripts/lol2/static_assemblies.gd").new()
		add_child(preview_assemblies)
		var error: String = preview_assemblies.setup(self, "L9_DR", [122,82], [], [], false)
		if not error.is_empty(): push_error(error)
	if region_blockers_enabled:
		preview_blockers = preload("res://scripts/lol2/region_blockers.gd").attach(self, player, "L9_DR")

	if get_tree().has_meta("lol2_map_start_selector"):
		var selector := int(get_tree().get_meta("lol2_map_start_selector"))
		get_tree().remove_meta("lol2_map_start_selector")
		var pose: Dictionary = Binder.arrival_pose("L9_DR", data, selector)
		if not pose.is_empty():
			start_selector = selector
			player.position = pose.position
			player.rotation.y = -TAU * float(pose.heading) / 65536.0
		else: push_error("Missing native arrival L9_DR/%d" % selector)
	if get_tree().has_meta("lol2_level_change"):
		arrived_by_level_change = bool(get_tree().get_meta("lol2_level_change"))
		get_tree().remove_meta("lol2_level_change")
	if get_tree().has_meta("lol2_map_preview"): get_tree().remove_meta("lol2_map_preview")
	if Binder.assets_ready("L9_DR"):
		progression = Binder.new()
		add_child(progression)
		var binder_error: String = progression.setup(self, "L9_DR")
		if not binder_error.is_empty(): push_error(binder_error)

	act2_creatures = preload("res://scripts/lol2/act2_creatures.gd").attach(self, "L9_DR")

	act2_items = preload("res://scripts/lol2/act2_world_items.gd").attach(self, "L9_DR")
	preload("res://scripts/lol2/act2_chargers.gd").attach(self, "L9_DR")
	preload("res://scripts/lol2/l9_magic_bridge.gd").attach(self)
	preload("res://scripts/lol2/l9_tower.gd").attach(self)
	preload("res://scripts/lol2/l9_dead_bracers.gd").attach(self)
	preload("res://scripts/lol2/l9_mirrors.gd").attach(self)
	preload("res://scripts/lol2/l9_noble_rails.gd").attach(self)
	preload("res://scripts/lol2/l9_pyre.gd").attach(self)
	preload("res://scripts/lol2/l9_statue.gd").attach(self)
	preload("res://scripts/lol2/l9_statue_walk.gd").attach(self)
	preload("res://scripts/lol2/l9_flood.gd").attach(self)
	preload("res://scripts/lol2/l9_journal_hints.gd").attach(self)
	preload("res://scripts/lol2/l9_escape.gd").attach(self)

func apply_save(state: Variant) -> String:
	var error := preload("res://scripts/lol2/act2_save.gd").validate(state, area_save_format)
	if not error.is_empty(): return error
	error = super.apply_save(state)
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	if error.is_empty() and has_node("L9Escape"): get_node("L9Escape").restore(true)
	if error.is_empty() and has_node("L9StatueWalk"): get_node("L9StatueWalk").restore()
	return error

func apply_area_handoff(state: Variant) -> String:
	if not state is Dictionary: return "Invalid area handoff."
	var error := preload("res://scripts/lol2/act2_save.gd").quests_error(state.get("quests"))
	if not error.is_empty(): return error
	if state.get("inventory", {}).get("collected", []).size() + state.get("quests", {}).get("act2_items", {}).get("carried", []).size() > 64: return "Inventory exceeds capacity."
	error = super.apply_area_handoff(state)
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	if error.is_empty() and has_node("L9Escape"): get_node("L9Escape").restore(true)
	if error.is_empty() and has_node("L9StatueWalk"): get_node("L9StatueWalk").restore()
	return error
func _quicksave_unrecorded(path: String = "") -> String:
	return preload("res://scripts/lol2/act2_save.gd").save_host(self, path)
func _quickload_unrecorded(path: String = "") -> String:
	return preload("res://scripts/lol2/act2_save.gd").load_host(self, path)

func inventory_state() -> Dictionary:
	preload("res://scripts/lol2/act2_items_catalog.gd").sync(self)
	var result := super.inventory_state()
	result.collected = result.collected.filter(func(id): return not preload("res://scripts/lol2/act2_items_catalog.gd").valid(id) or preload("res://scripts/lol2/act2_items_catalog.gd").legacy_equipment(id))
	return result

func _jump_input_active()->bool:
	return super._jump_input_active() or (DisplayServer.get_name()=="headless" and is_instance_valid(starting_magic) and starting_magic.interface_request)
