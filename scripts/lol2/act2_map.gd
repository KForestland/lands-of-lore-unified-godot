extends "res://scripts/lol2/jungle_walkthrough.gd"
## One Act 2/3 map pack (tools/prepare_map_portable.py --area AREA -> assets/lol2/generated/maps/AREA/area.json) hosted at the
## Act 1 Jungle standard: the L8 darker_jungle.gd recipe with an area argument. Floors (incl. the selector-255 floorless
## collision floors), ceilings, the original's rendered source walls (drawn, not collidable: native movement is region-based),
## static-assembly and movable faces, batched fixed-Y prop billboards with the native frame flips (prop_billboards.gd), the
## original panorama (map_sky/AREA), the native solid boxes (static_collision_AREA.json, collision only) and the native bit0
## region blockers (region_blockers/AREA.json), always on. No progression scripts here: doors, triggers and level changes come
## through the native script host. The player starts at the pack's native arrival (start_selector, witnessed in the pack).
const MAPS_ROOT := "res://assets/lol2/generated/maps/"
const SKY_ROOT := "res://assets/lol2/generated/map_sky/"
const REGISTRY := "res://scripts/lol2/act2_maps.json"
@export var map_blockers_enabled := true
@export var sector_light_enabled := true
var sector_lighting: Node = null
@export var area_id := "L10_DC"
var video_overlay:CanvasLayer
var preview_assemblies: Node3D
var preview_blockers := 0
var prop_batches := 0
var prop_instances := 0
var prop_placements: Dictionary = {}
var start_heading_units := 0
@export var adapter_exit_seeds := true
var progression: Node = null
var act2_items: Node3D
var act2_creatures: Node3D
var start_selector := -1
## True when this scene was entered by a native level change (meta lol2_level_change from act2_progression.gd); a gate
## preview, --map-preview or a test start leaves it false, and only then the binder applies its dev/test-start seeds.
var arrived_by_level_change := false

static func pack_path(area: String) -> String: return MAPS_ROOT + area + "/area.json"

## The gate's list of staged maps: [{area, scene, label, label_witness}], only those whose pack and images are present.
static func registry() -> Array:
	if not FileAccess.file_exists(REGISTRY): return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	if not data is Dictionary or not data.get("maps") is Array: return []
	var ready: Array = []
	for entry in data.maps:
		if entry is Dictionary and not bool(entry.get("travel_only", false)) and map_assets_ready(str(entry.get("area", ""))): ready.append(entry)
	return ready

static func map_assets_ready(area: String) -> bool:
	var path := pack_path(area)
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("materials") is Dictionary or not data.get("start") is Array: return false
	for file in data.materials.values():
		if not FileAccess.file_exists(path.get_base_dir()+"/"+file): return false
	return preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready()

func static_face_light(face: Dictionary) -> Color:
	if sector_lighting != null: return sector_lighting.face_light(face)
	return super.static_face_light(face)

## Areas drawn with portal visibility (owner 2026-11-05 Temple clipping). Others keep drawing every face.
const PORTAL_VISIBILITY_AREAS := ["L14_HT", "L10_DC", "L9_DR", "L16_CA", "L19_BC", "L20_BB"]
var region_visibility: Node
func _ready() -> void:
	region_blockers_enabled = map_blockers_enabled
	# Exported fields are set before _ready, so the per-area sky pack is chosen here (the base reads sky_pack in its _ready).
	sky_pack = SKY_ROOT + area_id + "/"
	preload("res://scripts/lol2/act3_journal_hints.gd").attach(self)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
	if area_id in preload("res://scripts/lol2/act2_sector_light.gd").AREAS:
		sector_lighting = preload("res://scripts/lol2/act2_sector_light.gd").new()
		sector_lighting.configure(area_id, data)
		add_child(sector_lighting)
		vertex_light_enabled = true
	# A level change or the gate may name another arrival of this level (meta lol2_map_start_selector): the pack keeps
	# every arrival record, so the start moves there (x, the pack's start height, -y) with that arrival's heading.
	start_selector = int(data.get("start_selector", -1))
	var start_override: Variant = null
	if get_tree().has_meta("lol2_map_start_selector"):
		var selector: int = int(get_tree().get_meta("lol2_map_start_selector"))
		get_tree().remove_meta("lol2_map_start_selector")
		var pose: Dictionary = preload("res://scripts/lol2/act2_progression.gd").arrival_pose(area_id, data, selector)
		if not pose.is_empty(): start_override = pose
		else: push_error("Missing native arrival %s/%d" % [area_id, selector])
	# The progression binder draws rotary scripted movables on hinges: their faces stay out of the static mesh.
	var Binder := preload("res://scripts/lol2/act2_progression.gd")
	if Binder.assets_ready(area_id): excluded_faces.merge(Binder.hinge_faces(area_id, data))
	if area_id=="L10_DC":
		for i in data.faces.size():
			var face: Dictionary=data.faces[i]
			if preload("res://scripts/lol2/l10_oil.gd").owns(face) or preload("res://scripts/lol2/l10_emperor_entry.gd").entry_owns(face) or preload("res://scripts/lol2/l10_emperor.gd").owns(face):excluded_faces[i]=true
			if face.get("placement_kind")=="static_assembly" and (int(face.get("source_index",-1)) in [61,70,165,166,167,168,169,170,171,172,173] or int(face.get("source_index",-1)) in preload("res://scripts/lol2/l10_tomb_state.gd").doors()): excluded_faces[i]=true
	if area_id=="L13_RC":
		for i in data.faces.size():
			if preload("res://scripts/lol2/l13_egg_door.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l13_eggs.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l13_elevator.gd").owns_lift(data.faces[i]) or preload("res://scripts/lol2/l13_spires.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l13_bridge.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l13_altar.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l13_exit_lock.gd").owns(data.faces[i]):excluded_faces[i]=true
	if area_id=="L12_CM":
		for i in data.faces.size():
			if (preload("res://scripts/lol2/l12_glacier.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l12_river_rafts.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l12_crevasse.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l12_frozen_bow.gd").owns(data.faces[i])):excluded_faces[i]=true
	if area_id=="L16_CA":
		for i in data.faces.size():
			if preload("res://scripts/lol2/l16_arrival_elevator.gd").owns(data.faces[i]):excluded_faces[i]=true
	if area_id=="L14_HT":
		for i in data.faces.size():
			if preload("res://scripts/lol2/l14_belial.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_hopper_platform.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_idol_pedestals.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_trap_route.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_flute_slot.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_fire_paths.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_tilt.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_trials.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_spiral.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_shard_bowls.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_niche.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_library.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_bedroom.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_spider_passage.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_machines.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_hanging.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_temple_doors.gd").owns(data.faces[i]) or preload("res://scripts/lol2/l14_priest_ritual.gd").owns(data.faces[i]):excluded_faces[i]=true
	# Portal visibility (region_visibility.gd, DEVIATIONS 2026-11-05): batch static faces per region cluster first.
	var visibility_nav: Array = []
	if area_id in PORTAL_VISIBILITY_AREAS and not get_tree().has_meta("lol2_portal_visibility_off"):
		visibility_nav = preload("res://scripts/lol2/region_visibility.gd").load_regions(area_id)
		if not visibility_nav.is_empty(): region_cluster = preload("res://scripts/lol2/region_visibility.gd").clusters(visibility_nav)
	super._ready()
	preload("res://scripts/lol2/act2_visuals.gd").apply(self, area_id)
	if start_override != null:
		data["start_heading_units"] = int(start_override.heading)
		start_selector = int(start_override.selector)
		player.position = start_override.position
	var batched: Dictionary = preload("res://scripts/lol2/prop_billboards.gd").batch(self, data, geometry_file, "MapProps")
	prop_batches = batched.batches
	prop_instances = batched.instances
	prop_placements = batched.placements
	# Native arrival heading units (65536 per turn) to the scene yaw: the L8 adapter (16384 -> -PI/2) applied linearly.
	start_heading_units = int(data.get("start_heading_units", 0))
	player.rotation.y = -TAU * float(start_heading_units) / 65536.0
	var assemblies := preload("res://scripts/lol2/static_assemblies.gd")
	if assemblies.assets_ready(area_id) and FileAccess.file_exists("res://scripts/lol2/static_collision_%s.json" % area_id):
		preview_assemblies = assemblies.new()
		add_child(preview_assemblies)
		var collision_error: String = preview_assemblies.setup(self, area_id, [], [64,75,124] if area_id=="L14_HT" else ([194] if area_id=="L16_CA" else []), [], false)
		if not collision_error.is_empty(): push_error(collision_error)
	if region_blockers_enabled: preview_blockers = preload("res://scripts/lol2/region_blockers.gd").attach(self, player, area_id)
	if get_tree().has_meta("lol2_map_preview"): get_tree().remove_meta("lol2_map_preview")
	if get_tree().has_meta("lol2_level_change"):
		arrived_by_level_change = bool(get_tree().get_meta("lol2_level_change"))
		get_tree().remove_meta("lol2_level_change")
	# Progression through the native script host (act2_progression.gd) when the level's scripts are staged.
	if Binder.assets_ready(area_id):
		progression = Binder.new()
		add_child(progression)
		var binder_error: String = progression.setup(self, area_id)
		if not binder_error.is_empty(): push_warning("act2_map %s: progression not bound (%s)" % [area_id, binder_error])

	act2_creatures = preload("res://scripts/lol2/act2_creatures.gd").attach(self, area_id)

	act2_items = preload("res://scripts/lol2/act2_world_items.gd").attach(self, area_id)
	preload("res://scripts/lol2/act2_chargers.gd").attach(self, area_id)
	if area_id=="L10_DC":
		preload("res://scripts/lol2/l10_main_gate.gd").attach(self)
		preload("res://scripts/lol2/l10_tombs.gd").attach(self)
		preload("res://scripts/lol2/l10_braziers.gd").attach(self)
		preload("res://scripts/lol2/l10_fences.gd").attach(self)
		preload("res://scripts/lol2/l10_barrel.gd").attach(self)
		preload("res://scripts/lol2/l10_oil.gd").attach(self)
		preload("res://scripts/lol2/l10_priest.gd").attach(self)
		preload("res://scripts/lol2/l10_emperor_entry.gd").attach_entry(self)
		preload("res://scripts/lol2/l10_emperor.gd").attach(self)
		preload("res://scripts/lol2/l10_silverleaf.gd").attach(self)
		preload("res://scripts/lol2/l10_journal_hints.gd").attach(self)
		preload("res://scripts/lol2/l8_tribe_dawn_hints.gd").attach(self, "remains")
	if area_id=="L13_RC":
		preload("res://scripts/lol2/l13_egg_door.gd").attach(self)
		preload("res://scripts/lol2/l13_eggs.gd").attach(self)
		preload("res://scripts/lol2/l13_elevator.gd").attach_lift(self)
		preload("res://scripts/lol2/l13_prison.gd").attach(self)
		preload("res://scripts/lol2/l13_spires.gd").attach(self)
		preload("res://scripts/lol2/l13_dawn_prison.gd").attach(self)
		preload("res://scripts/lol2/l13_bridge.gd").attach(self)
		preload("res://scripts/lol2/l13_belial.gd").attach(self)
		preload("res://scripts/lol2/l13_altar.gd").attach(self)
		preload("res://scripts/lol2/l13_return_pad.gd").attach(self)
		preload("res://scripts/lol2/l13_exit_lock.gd").attach(self)
		preload("res://scripts/lol2/l13_journal_hints.gd").attach(self, "citadel")
	if not region_cluster.is_empty() and progression != null:
		region_visibility = preload("res://scripts/lol2/region_visibility.gd").new()
		add_child(region_visibility)
		region_visibility.setup(self, area_id, visibility_nav, region_cluster, cluster_meshes)
	if area_id=="L17_HC" and progression != null:
		preload("res://scripts/lol2/l17_cavern_run.gd").attach(self)
		preload("res://scripts/lol2/l17_beast_blade.gd").attach(self)
	if area_id=="L16_CA" and progression != null:
		preload("res://scripts/lol2/l16_nw_traps.gd").attach(self)
		preload("res://scripts/lol2/l16_arrival_elevator.gd").attach(self)
		preload("res://scripts/lol2/l16_greenhouse.gd").attach(self)
		preload("res://scripts/lol2/l16_sw_chips.gd").attach(self)
		preload("res://scripts/lol2/l16_dry_fountain.gd").attach(self)
		preload("res://scripts/lol2/l16_ne_tower.gd").attach(self)
		preload("res://scripts/lol2/l16_centre_tower.gd").attach(self)
		preload("res://scripts/lol2/l16_journal_hints.gd").attach(self)
		preload("res://scripts/lol2/l16_se_oil.gd").attach(self)
		preload("res://scripts/lol2/l16_dragon_room.gd").attach(self)
	if area_id=="L14_HT":
		preload("res://scripts/lol2/l14_temple_doors.gd").attach(self)
		preload("res://scripts/lol2/l14_hall_clear.gd").attach(self)
		preload("res://scripts/lol2/l14_priest_body.gd").attach(self)
		preload("res://scripts/lol2/l14_priest_ritual.gd").attach(self)
		preload("res://scripts/lol2/l14_post_shard.gd").attach(self)
		preload("res://scripts/lol2/l14_hanging.gd").attach(self)
		preload("res://scripts/lol2/l14_bedroom.gd").attach(self)
		preload("res://scripts/lol2/l14_library.gd").attach(self)
		preload("res://scripts/lol2/l14_quill.gd").attach(self)
		preload("res://scripts/lol2/l14_niche.gd").attach(self)
		preload("res://scripts/lol2/l14_shard_bowls.gd").attach(self)
		preload("res://scripts/lol2/l14_spiral.gd").attach(self)
		preload("res://scripts/lol2/l14_trials.gd").attach(self)
		preload("res://scripts/lol2/l14_tilt.gd").attach(self)
		preload("res://scripts/lol2/l14_fire_paths.gd").attach(self)
		preload("res://scripts/lol2/l14_flute_slot.gd").attach(self)
		preload("res://scripts/lol2/l14_chamber_voices.gd").attach(self)
		preload("res://scripts/lol2/l14_trap_route.gd").attach(self)
		preload("res://scripts/lol2/l14_idol_pedestals.gd").attach(self)
		preload("res://scripts/lol2/l14_hopper_platform.gd").attach(self)
		preload("res://scripts/lol2/l14_journal_hints.gd").attach(self)
		preload("res://scripts/lol2/l14_belial.gd").attach(self)
		preload("res://scripts/lol2/l14_spider_passage.gd").attach(self)
		preload("res://scripts/lol2/l14_spider_burrow.gd").attach(self)
		preload("res://scripts/lol2/l14_lower_passage.gd").attach(self)
		preload("res://scripts/lol2/l14_machines.gd").attach(self)
	if area_id=="L19_BC" and progression != null:
		preload("res://scripts/lol2/l19_beast_wall.gd").attach(self)
		preload("res://scripts/lol2/l19_belial_horn.gd").attach(self)
		preload("res://scripts/lol2/l19_sewer_forms.gd").attach(self)
		preload("res://scripts/lol2/l19_drain_path.gd").attach(self)
		preload("res://scripts/lol2/l19_ghostly_heads.gd").attach(self)
		preload("res://scripts/lol2/l19_dawn_curse.gd").attach(self)
	if area_id=="L20_BB" and progression != null:
		preload("res://scripts/lol2/l19_dawn_curse.gd").attach(self)
		preload("res://scripts/lol2/l20_pillars_scotia.gd").attach(self)
		preload("res://scripts/lol2/l20_armory.gd").attach(self)
		preload("res://scripts/lol2/l20_faux_draracle.gd").attach(self)
		preload("res://scripts/lol2/l20_finale.gd").attach(self)
	if area_id=="L12_CM":
		preload("res://scripts/lol2/l12_glacier.gd").attach(self)
		preload("res://scripts/lol2/l12_river_rafts.gd").attach(self)
		preload("res://scripts/lol2/l12_niche_armor.gd").attach(self)
		preload("res://scripts/lol2/l12_crevasse.gd").attach(self)
		preload("res://scripts/lol2/l12_frozen_bow.gd").attach(self)
		preload("res://scripts/lol2/l12_citadel.gd").attach(self)
	if sector_lighting != null:
		sector_lighting.apply(self)
		sector_lighting.set_enabled(sector_light_enabled)

func include_collision_face(face: Dictionary) -> bool:
	if area_id=="L16_CA" and preload("res://scripts/lol2/l16_arrival_elevator.gd").owns(face):return false
	if area_id=="L14_HT" and (preload("res://scripts/lol2/l14_belial.gd").owns(face) or preload("res://scripts/lol2/l14_hopper_platform.gd").owns(face) or preload("res://scripts/lol2/l14_idol_pedestals.gd").owns(face) or preload("res://scripts/lol2/l14_trap_route.gd").owns(face) or preload("res://scripts/lol2/l14_flute_slot.gd").owns(face) or preload("res://scripts/lol2/l14_fire_paths.gd").owns(face) or preload("res://scripts/lol2/l14_tilt.gd").owns(face) or preload("res://scripts/lol2/l14_trials.gd").owns(face) or preload("res://scripts/lol2/l14_spiral.gd").owns(face) or preload("res://scripts/lol2/l14_shard_bowls.gd").owns(face) or preload("res://scripts/lol2/l14_niche.gd").owns(face) or preload("res://scripts/lol2/l14_library.gd").owns(face) or preload("res://scripts/lol2/l14_bedroom.gd").owns(face) or preload("res://scripts/lol2/l14_spider_passage.gd").owns(face) or preload("res://scripts/lol2/l14_machines.gd").owns(face) or preload("res://scripts/lol2/l14_hanging.gd").owns(face) or preload("res://scripts/lol2/l14_temple_doors.gd").owns(face) or preload("res://scripts/lol2/l14_priest_ritual.gd").owns(face)):return false
	if area_id=="L12_CM" and preload("res://scripts/lol2/l12_glacier.gd").owns_upper(face):return false
	if area_id=="L13_RC" and (preload("res://scripts/lol2/l13_egg_door.gd").owns(face) or preload("res://scripts/lol2/l13_eggs.gd").owns(face) or preload("res://scripts/lol2/l13_elevator.gd").owns_lift(face) or preload("res://scripts/lol2/l13_spires.gd").owns(face) or preload("res://scripts/lol2/l13_bridge.gd").owns(face) or preload("res://scripts/lol2/l13_altar.gd").owns(face) or preload("res://scripts/lol2/l13_exit_lock.gd").owns(face)):return false
	if area_id=="L12_CM" and (preload("res://scripts/lol2/l12_glacier.gd").owns(face) or preload("res://scripts/lol2/l12_river_rafts.gd").owns(face) or preload("res://scripts/lol2/l12_crevasse.gd").owns(face) or preload("res://scripts/lol2/l12_frozen_bow.gd").owns(face)):return false
	if area_id=="L10_DC" and preload("res://scripts/lol2/l10_emperor.gd").owns(face):return false
	if area_id=="L10_DC" and preload("res://scripts/lol2/l10_emperor_entry.gd").entry_owns(face):return false
	if area_id=="L10_DC" and preload("res://scripts/lol2/l10_oil.gd").owns(face):return false
	if area_id=="L10_DC" and face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1)) in [70,74,75,174]: return false
	if area_id=="L10_DC" and face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1)) in preload("res://scripts/lol2/l10_tomb_state.gd").doors(): return false
	if area_id=="L10_DC" and face.get("placement_kind")=="static_assembly" and preload("res://scripts/lol2/l10_tomb_state.gd").ROWS.has(str(int(face.get("source_index",-1)))): return false
	# L10 control67 has source flags0x0402 (not solid); its picture must not seal the entrance.
	if area_id=="L10_DC" and face.get("placement_kind")=="static_assembly" and face.get("source_index")==67: return false
	if bool(face.get("source_wall", false)): return false
	return super.include_collision_face(face)

func apply_save(state: Variant) -> String:
	var error := preload("res://scripts/lol2/act2_save.gd").validate(state, area_save_format)
	if not error.is_empty(): return error
	error = super.apply_save(state)
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	if error.is_empty() and has_node("L10Fences"):get_node("L10Fences").restore()
	if error.is_empty() and has_node("L12FrozenBow"):get_node("L12FrozenBow").restore()
	if error.is_empty() and has_node("L12Crevasse"):get_node("L12Crevasse").restore()
	if error.is_empty() and has_node("L12NicheArmor"):get_node("L12NicheArmor").restore()
	if error.is_empty() and has_node("L12RiverRafts"):get_node("L12RiverRafts").restore()
	if error.is_empty() and has_node("L12Glacier"):get_node("L12Glacier").restore()
	if error.is_empty() and has_node("L13EggDoor"):get_node("L13EggDoor").restore()
	if error.is_empty() and has_node("L13Eggs"):get_node("L13Eggs").restore()
	if error.is_empty() and has_node("L13Elevator"):get_node("L13Elevator").restore()
	if error.is_empty() and has_node("L13Spires"):get_node("L13Spires").restore()
	if error.is_empty() and has_node("L13Bridge"):get_node("L13Bridge").restore()
	if error.is_empty() and has_node("L13Altar"):get_node("L13Altar").restore()
	if error.is_empty() and has_node("L13ExitLock"):get_node("L13ExitLock").restore()
	return error

func apply_area_handoff(state: Variant) -> String:
	if not state is Dictionary: return "Invalid area handoff."
	var error := preload("res://scripts/lol2/act2_save.gd").quests_error(state.get("quests"))
	if not error.is_empty(): return error
	if state.get("inventory", {}).get("collected", []).size() + state.get("quests", {}).get("act2_items", {}).get("carried", []).size() > 64: return "Inventory exceeds capacity."
	error = super.apply_area_handoff(state)
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
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

func jump_launch_speed(sprint:bool=false)->float:
	if has_node("L12RiverRafts"):return get_node("L12RiverRafts").jump_speed(sprint)
	return super.jump_launch_speed(sprint)

func move_grounded(direction: Vector3,delta: float,sprint: bool=false)->void:
	if has_node("L10Fences"):get_node("L10Fences").prepare(direction,sprint)
	super.move_grounded(direction,delta,sprint)

func _jump_input_active()->bool:
	return super._jump_input_active() or (DisplayServer.get_name()=="headless" and is_instance_valid(starting_magic) and starting_magic.interface_request)

func use_inventory_item(id:String)->bool:
	if id==preload("res://scripts/lol2/l12_citadel_state.gd").PICTURE and has_node("L12Citadel"):return get_node("L12Citadel").arm(id)
	return super.use_inventory_item(id)
