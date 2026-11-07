extends "res://scripts/lol2/jungle_walkthrough.gd"
## Original L8_SJ terrain/initial scenery; the connected Act1 arrival and (Phase A, 2026-10-30) the full darker-jungle map at the
## Act 1 Jungle standard: the pack's floors (incl. the 44 floorless collision floors), ceilings, source walls, static assemblies and
## movables, 1765 props as batched fixed-Y billboards with the native frame flips, the original night panorama
## (darker_jungle_sky), the native solid boxes of the static assemblies and the native bit0 region blockers, always on.
const FORMAT := "lol2-restoration-darker-jungle"
const DEFAULT_PATH := "user://saves/darker_jungle_quicksave.json"
const DARKER_SKY := "res://assets/lol2/generated/darker_jungle_sky/"
static func arrival_assets_ready() -> bool:
	var path := "res://assets/lol2/generated/darker_jungle/area.json"
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("materials") is Dictionary: return false
	for file in data.materials.values():
		if not FileAccess.file_exists(path.get_base_dir()+"/"+file): return false
	return preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready()
## Owner-approved removal (r12e F10 2026-10-25 11:05, "the road is blocked to dark jungle"): the vine arch at the root
## tunnel exit (static assembly 99, template 8) is drawn but no longer collides. Its drawn quads filled the whole
## opening; the original lists no solid box for it (placement word8 bit 0x80 clear). Every other face still collides.
## Larkhon cave facade111 also has no native solid box; its original dynamic regions own admission (STORY035).
const OPEN_ASSEMBLIES := [99,111]
## The native solid boxes of the static assemblies (static_collision_L8_SJ.json, collision only: the pack already draws every
## assembly face) and the native player-impassable regions (region_blockers/L8_SJ.json); the l8-preview lane gated them, Phase A
## attaches them always (the Act 1 Jungle rule). The gate's "Preview: Act 2 start" entry is offered in both editions (owner, 2026-10-30).
var preview_assemblies: Node3D
var preview_blockers := 0
## Progression through the native script host (act2_progression.gd, as act2_map.gd attaches it): region-entry events, level
## changes, E on scripted movables, and the live opcode-197 toggle of the five dynamic blocker regions (2026-10-31; the
## static exclusion of those regions is replaced by their data bit 0 until a script changes it). Hinges stay off here: the
## pack draws every movable statically.
@export var adapter_exit_seeds := true
var progression: Node = null
var act2_items: Node3D
var act2_creatures: Node3D
var start_selector := -1
var arrived_by_level_change := false
## Prop batches (scripts/lol2/prop_billboards.gd): one MultiMesh per (material, box, flip), every pack row at its native
## placement, first frame only (no L8 frame rate is proven, as for the Hive/Jungle scenery); record -> [MultiMesh, index, position].
var prop_batches := 0
var prop_instances := 0
var prop_placements: Dictionary = {}
## Night shading (lead 2026-10-31, option A of L8_TREE_TOPS_FINDING_20261031.md): every static face (incl. the assembly faces the
## pack draws as kind "movable"), prop billboard and movable is drawn through scripts/lol2/l8_night.gd with its native sector light
## (ambient level and the fade to black over the sector's near/span, the original 0x1319B4 row). Faces without a bound light (the
## 948 assembly faces, 44 floorless floors) take their region's light. night_fog_only = option B (the fade without the level)
## behind a flag; night_enabled false = the full-bright draw of r12r (scene meta lol2_l8_night {enabled, fog_only}). The native
## panorama allows about 37.6 degrees of look-up (1280x300 rows, vertical_origin 42, half-pixel steps, focal 409.6 px): the mouse
## pitch is clamped to that (option D; the same limit downward is an adapter).
const Night := preload("res://scripts/lol2/l8_night.gd")
const PITCH_LIMIT := 0.656
var night_enabled := true
var night_fog_only := false
var night_materials: Array[ShaderMaterial] = []
var night_region_faces := 0
var _region_light: Dictionary = {}
## Floor outlines by 512-unit cell ([PackedVector2Array, region]) so a face without a region (the 948 assembly faces) is lit by
## the region under its centre (stacked regions are not told apart: an adapter for the few overlaps).
var _floor_cells: Dictionary = {}
const FLOOR_CELL := 512.0
static func preview_mode() -> bool:
	if "--l8-preview" in OS.get_cmdline_user_args(): return true
	if preload("res://scripts/lol2/enhanced/enhanced_edition.gd").enabled(): return true
	return Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).has_meta("lol2_darker_preview")
func include_collision_face(face: Dictionary) -> bool:
	if preload("res://scripts/lol2/l8_tree.gd").owns(face):return false
	if preload("res://scripts/lol2/l8_tree_bridge.gd").owns(face):return false
	return not (face.kind == "movable" and face.get("placement_kind") == "static_assembly" and int(face.get("source_index", -1)) in OPEN_ASSEMBLIES)

func _init() -> void:
	super._init()
	sky_pack = DARKER_SKY
	vertex_light_enabled = true
	pitch_limit = PITCH_LIMIT

## CUSTOM0 of every static face: its own sector light, else the light of its region (floor faces carry the region's sector).
func static_face_light(face: Dictionary) -> Color:
	var light: Variant = face.get("sector_light")
	if light is Array and (light as Array).size() >= 4:
		return Color(float(light[0]), float(light[1]), float(light[2]), float(light[3]))
	var region: Variant = face.get("region")
	if not (region is float or region is int):
		var centre := Vector2.ZERO
		for point in face.points: centre += Vector2(float(point[0]), float(point[2]))
		region = _region_at_xz(centre / float(face.points.size()))
	if (region is float or region is int) and _region_light.has(int(region)):
		night_region_faces += 1
		return _region_light[int(region)]
	return Color(63, 9999, 9999, 128)

func _region_at_xz(p: Vector2) -> int:
	for row in _floor_cells.get(Vector2i(floori(p.x / FLOOR_CELL), floori(p.y / FLOOR_CELL)), []):
		if Geometry2D.is_point_in_polygon(p, row[0]): return int(row[1])
	return -1

## Night materials on every static mesh (CUSTOM0 sector) and prop batch (INSTANCE_CUSTOM from the rows' sector light).
func _apply_night() -> void:
	night_materials.clear()
	for mesh in static_meshes:
		if mesh.mesh == null or mesh.mesh.get_surface_count() == 0: continue
		var source: Material = mesh.mesh.surface_get_material(0)
		if not source is StandardMaterial3D: continue
		var material := Night.material_for(source, Night.SOURCE_CUSTOM0, Night.FULL_BRIGHT, night_fog_only)
		mesh.material_override = material
		night_materials.append(material)
	for child in get_children():
		if child is MultiMeshInstance3D and str(child.name).begins_with("DarkerProps") and child.multimesh != null and child.multimesh.mesh != null:
			var source: Material = child.multimesh.mesh.material
			if not source is StandardMaterial3D: continue
			var material := Night.material_for(source, Night.SOURCE_INSTANCE, Night.FULL_BRIGHT, night_fog_only)
			child.multimesh.mesh.material = material
			night_materials.append(material)

func set_night(enabled: bool, fog_only: bool) -> void:
	night_enabled = enabled
	night_fog_only = fog_only
	for material in night_materials:
		material.set_shader_parameter("night_enabled", enabled)
		material.set_shader_parameter("fog_only", fog_only)

var area_world_items: Node3D


func _ready() -> void:
	if get_tree().has_meta("lol2_l8_night"):
		var wanted: Variant = get_tree().get_meta("lol2_l8_night")
		get_tree().remove_meta("lol2_l8_night")
		if wanted is Dictionary:
			night_enabled = bool(wanted.get("enabled", true))
			night_fog_only = bool(wanted.get("fog_only", false))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
	for face in data.faces:
		if face.kind == "floor" and (face.get("region") is float or face.get("region") is int) and face.get("sector_light") is Array:
			_region_light[int(face.region)] = Color(float(face.sector_light[0]), float(face.sector_light[1]), float(face.sector_light[2]), float(face.sector_light[3]))
			var outline := PackedVector2Array()
			var box := Rect2(float(face.points[0][0]), float(face.points[0][2]), 0, 0)
			for point in face.points:
				var p := Vector2(float(point[0]), float(point[2]))
				outline.append(p); box = box.expand(p)
			for x in range(floori(box.position.x / FLOOR_CELL), floori(box.end.x / FLOOR_CELL) + 1):
				for y in range(floori(box.position.y / FLOOR_CELL), floori(box.end.y / FLOOR_CELL) + 1):
					var cell := Vector2i(x, y)
					if not _floor_cells.has(cell): _floor_cells[cell] = []
					_floor_cells[cell].append([outline, int(face.region)])
	var Binder := preload("res://scripts/lol2/act2_progression.gd")
	if Binder.assets_ready("L8_SJ"): excluded_faces.merge(Binder.hinge_faces("L8_SJ", data))
	for i in data.faces.size():
		if preload("res://scripts/lol2/l8_tree.gd").owns(data.faces[i]):excluded_faces[i]=true
		if preload("res://scripts/lol2/l8_tree_bridge.gd").owns(data.faces[i]):excluded_faces[i]=true
	super._ready()
	# Drowning in this area's water regions (liquid_drowning.gd, owner 2026-10-31): staged by tools/prepare_liquid_regions.py.
	if preload("res://scripts/lol2/liquid_drowning.gd").assets_ready("L8_SJ"):
		liquid_drowning = preload("res://scripts/lol2/liquid_drowning.gd").new()
		add_child(liquid_drowning)
		var liquid_error: String = liquid_drowning.setup(self, "L8_SJ")
		if not liquid_error.is_empty(): push_warning(liquid_error)
	# Original world-item rows of this level (area_world_items_state.gd "darkerjungle"), the Jungle rows' pickup with an area argument.
	if preload("res://scripts/lol2/area_world_items.gd").assets_ready("darkerjungle"):
		area_world_items = preload("res://scripts/lol2/area_world_items.gd").new()
		add_child(area_world_items)
		var area_items_error: String = area_world_items.setup(self, "darkerjungle")
		if not area_items_error.is_empty(): push_warning(area_items_error)
	var batched: Dictionary = preload("res://scripts/lol2/prop_billboards.gd").batch(self, data, geometry_file, "DarkerProps")
	prop_batches = batched.batches
	prop_instances = batched.instances
	prop_placements = batched.placements
	player.rotation.y = -PI/2
	if preload("res://scripts/lol2/static_assemblies.gd").assets_ready("L8_SJ") and FileAccess.file_exists("res://scripts/lol2/static_collision_L8_SJ.json"):
		preview_assemblies = preload("res://scripts/lol2/static_assemblies.gd").new()
		add_child(preview_assemblies)
		var collision_error: String = preview_assemblies.setup(self, "L8_SJ", [], [], [114, 116], false)
		if not collision_error.is_empty(): push_error(collision_error)
		else:
			var solid_error: String = preview_assemblies.add_scripted_solids("L8_SJ", [114, 116])
			if not solid_error.is_empty(): push_error(solid_error)
	if region_blockers_enabled: preview_blockers = preload("res://scripts/lol2/region_blockers.gd").attach(self, player, "L8_SJ")
	if get_tree().has_meta("lol2_darker_preview"): get_tree().remove_meta("lol2_darker_preview")
	if get_tree().has_meta("lol2_level_change"):
		arrived_by_level_change = bool(get_tree().get_meta("lol2_level_change"))
		get_tree().remove_meta("lol2_level_change")
	if get_tree().has_meta("lol2_map_start_selector"):
		var selector := int(get_tree().get_meta("lol2_map_start_selector"))
		get_tree().remove_meta("lol2_map_start_selector")
		var pose: Dictionary = Binder.arrival_pose("L8_SJ", data, selector)
		if not pose.is_empty():
			start_selector = selector
			player.position = pose.position
			player.rotation.y = -TAU * float(pose.heading) / 65536.0
		else: push_error("Missing native arrival L8_SJ/%d; regenerate darker_jungle pack" % selector)
	if get_tree().has_meta("lol2_map_preview"): get_tree().remove_meta("lol2_map_preview")
	if Binder.assets_ready("L8_SJ"):
		progression = Binder.new()
		progression.hinges_enabled = true
		add_child(progression)
		var binder_error: String = progression.setup(self, "L8_SJ")
		if not binder_error.is_empty(): push_warning("darker_jungle: progression not bound (%s)" % binder_error)
	_apply_night()
	if not night_enabled: set_night(false, night_fog_only)
	if get_tree().has_meta("lol2_darker_handoff"):
		var error := apply_area_handoff(get_tree().get_meta("lol2_darker_handoff"))
		if error.is_empty(): get_tree().remove_meta("lol2_darker_handoff")
		else: push_error(error)
	if get_tree().has_meta("lol2_darker_resume"):
		var error := apply_save(get_tree().get_meta("lol2_darker_resume"))
		if error.is_empty(): get_tree().remove_meta("lol2_darker_resume")
		else: push_error(error)

	act2_creatures = preload("res://scripts/lol2/act2_creatures.gd").attach(self, "L8_SJ")

	act2_items = preload("res://scripts/lol2/act2_world_items.gd").attach(self, "L8_SJ")
	var journey = preload("res://scripts/lol2/l8_journey.gd").new()
	journey.host = self
	add_child(journey)
	preload("res://scripts/lol2/l8_village_hints.gd").attach(self)
	preload("res://scripts/lol2/l8_shore.gd").attach(self)
	preload("res://scripts/lol2/l8_dawn.gd").attach(self)
	preload("res://scripts/lol2/l8_baccata.gd").attach(self)
	preload("res://scripts/lol2/l8_tribe.gd").attach(self)
	preload("res://scripts/lol2/l8_tribe_dawn_hints.gd").attach(self, "tribe")
	preload("res://scripts/lol2/l8_clubhouse.gd").attach(self)
	preload("res://scripts/lol2/l8_huline_speech.gd").attach(self)
	preload("res://scripts/lol2/l8_larkhon.gd").attach(self)
	preload("res://scripts/lol2/l8_temple_door.gd").attach(self)
	preload("res://scripts/lol2/l13_journal_hints.gd").attach(self, "temple")
	preload("res://scripts/lol2/l8_tree_bridge.gd").attach(self)
	preload("res://scripts/lol2/l8_cache_ladder.gd").attach(self)
	preload("res://scripts/lol2/l8_tree.gd").attach(self)

func apply_save(state: Variant) -> String:
	var error := preload("res://scripts/lol2/act2_save.gd").validate(state, area_save_format)
	if not error.is_empty(): return error
	error = super.apply_save(state)
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	if error.is_empty() and has_node("L8Clubhouse"):get_node("L8Clubhouse").restore()
	if error.is_empty() and has_node("L8Larkhon"):get_node("L8Larkhon").restore()
	if error.is_empty() and has_node("L8TreeBridge"):get_node("L8TreeBridge").restore()
	if error.is_empty() and has_node("L8CacheLadder"):get_node("L8CacheLadder").restore()
	return error

func apply_area_handoff(state: Variant) -> String:
	if not state is Dictionary: return "Invalid area handoff."
	var error := preload("res://scripts/lol2/act2_save.gd").quests_error(state.get("quests"))
	if not error.is_empty(): return error
	if state.get("inventory", {}).get("collected", []).size() + state.get("quests", {}).get("act2_items", {}).get("carried", []).size() > 64: return "Inventory exceeds capacity."
	error = super.apply_area_handoff(state)
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	if error.is_empty() and has_node("L8Clubhouse"):get_node("L8Clubhouse").restore()
	if error.is_empty() and has_node("L8Larkhon"):get_node("L8Larkhon").restore()
	if error.is_empty() and has_node("L8TreeBridge"):get_node("L8TreeBridge").restore()
	if error.is_empty() and has_node("L8CacheLadder"):get_node("L8CacheLadder").restore()
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

func actor_input_locked() -> bool:
	var tribe=get_node_or_null("L8Tribe")
	var speech=get_node_or_null("L8HulineSpeech")
	return super.actor_input_locked() or (tribe!=null and tribe.input_locked()) or (speech!=null and speech.input_locked())

func use_inventory_item(id:String)->bool:
	if id==preload("res://scripts/lol2/l8_larkhon_state.gd").VAPORS:return get_node("L8Larkhon").activate(id)
	return super.use_inventory_item(id)

func _jump_input_active()->bool:
	return super._jump_input_active() or (DisplayServer.get_name()=="headless" and is_instance_valid(starting_magic) and starting_magic.interface_request)

## STORY048 / deviation0279: actual sprint flight from original east bank to west bank.
## Native jump strength is unentered; original terrain remains authoritative.
func jump_launch_speed(sprint: bool = false) -> float:
	if not sprint or player_form != 0:return super.jump_launch_speed(sprint)
	var lock=preload("res://scripts/lol2/l13_exit_lock_state.gd")
	if not lock.unlocked(quest_state.get(lock.KEY,lock.initial())):return super.jump_launch_speed(sprint)
	var takeoff:=Vector2(5399,1873.5)
	if Vector2(player.position.x,player.position.z).distance_to(takeoff)>35:return super.jump_launch_speed(sprint)
	if player.position.y < -180 or player.position.y > -130:return super.jump_launch_speed(sprint)
	var rise:float=0.0-(player.position.y-32.0)+24.0
	var travel:float=Vector2(player.position.x,player.position.z).distance_to(Vector2(5100,1880))/144.0
	return maxf(sqrt(640.0*rise),(rise+160.0*travel*travel)/travel)
