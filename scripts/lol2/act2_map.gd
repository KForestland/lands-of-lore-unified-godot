extends "res://scripts/lol2/jungle_walkthrough.gd"
## One Act 2/3 map pack (tools/prepare_map_portable.py --area AREA -> assets/lol2/generated/maps/AREA/area.json) hosted at the
## Act 1 Jungle standard: the L8 darker_jungle.gd recipe with an area argument. Floors (incl. the selector-255 floorless
## collision floors), ceilings, the original's rendered source walls (drawn, not collidable: native movement is region-based;
## L10 uses its validated height_boundary packet: a source wall on a side with no native neighbour collides),
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
var thin_region_blocks: Node = null
var prop_batches := 0
var prop_instances := 0
var prop_placements: Dictionary = {}
var start_heading_units := 0
@export var adapter_exit_seeds := true
## L10 boundary adapter A/B switch; its triangles must never alter the terrain trimesh.
@export var boundary_walls_enabled := true
var area_owners: Node
var progression: Node = null
const DREAMSTONE_HOME_LINE := "Carry the Dreamstone back to the Huline Temple: follow the ice tunnel to the opening over the river."
var act2_items: Node3D
var act2_creatures: Node3D
var start_selector := -1
var body_fit: RefCounted
## True when this scene was entered by a native level change (meta lol2_level_change from act2_progression.gd); a gate
## preview, --map-preview or a test start leaves it false, and only then the binder applies its dev/test-start seeds.
var arrived_by_level_change := false

static func pack_path(area: String) -> String: return MAPS_ROOT + area + "/area.json"

## Islands mode: a static face without a region (movable and static-assembly faces) joins the room its placement stands in
## (the nav region under the placement's centroid, nearest floor), so a door or a pedestal of a hidden room stays hidden too.
func static_face_cluster(face: Dictionary) -> int:
	var base := super.static_face_cluster(face)
	if base >= 0 or not island_mode or portal_nav.is_empty() or not face.has("points"): return base
	var placement: Variant = face.get("placement")
	var key: String = "%s:%s" % [str(face.get("placement_kind", "")), str(placement)] if placement != null else ""
	if not key.is_empty() and _placement_island.has(key): return int(_placement_island[key])
	var centre := Vector3.ZERO
	var count := 0
	for p in face.points: centre += Vector3(float(p[0]), float(p[1]), float(p[2])); count += 1
	if count == 0: return -1
	centre /= float(count)
	var region := preload("res://scripts/lol2/region_visibility.gd").region_at_nav(portal_nav, centre)
	var island := int(region_cluster.get(region, -1)) if region >= 0 else -1
	if not key.is_empty(): _placement_island[key] = island
	return island

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
const PORTAL_VISIBILITY_AREAS := ["L14_HT", "L10_DC", "L9_DR", "L16_CA", "L19_BC", "L20_BB", "L12_CM"]
## Region-edge rule (region_edge_rule.gd, BK01/BK02 2026-11-09): a vertical face at a region side blocks the player exactly
## where no walkable region lies beyond it. Per area until the other packs are walked with it.
const EDGE_RULE_AREAS := ["L17_HC", "L19_BC"]
## Region-aware collision (lead decision 2026-11-09, adapter restoring the original region-based mover): the static collision is
## kept per region (jungle_review) and only regions within COLLISION_HOPS nav hops of the player's region collide, so a second
## layout of corridors laid over the player's at the same height (L17 regions 1236 over 562) never stops the body.
const REGION_COLLISION_AREAS := ["L17_HC", "L19_BC"]
const COLLISION_HOPS := 8
const RegionEdgeRule := preload("res://scripts/lol2/region_edge_rule.gd")
var edge_block_keys: Dictionary = {}
var edge_rule_counts: Dictionary = {}
var nav_regions: Array = []
var collision_links: Dictionary = {}
var last_collision_region := -2
var active_collision_regions := 0
## Areas whose portal visibility works in islands (Fable TEMPLE-ISLANDS 2026-11-07): the batching unit is the original's room
## (every pack face's render_sector) and the view leaves a room only through an opening (region_visibility.gd). Other
## portal areas keep the 24-region clusters. Meta lol2_portal_islands_off restores the clusters for an A/B capture.
const ISLAND_AREAS := ["L14_HT", "L10_DC"]
## The black void with the panorama only through roofless ceilings (island_sky_ceilings.gd) - L14 only; L10's rooms use the
## island grouping for drawing (lead 2026-11-14: finer room grouping) and keep their sky as before.
const ISLAND_SKY_AREAS := ["L14_HT"]
## Native wall records are drawn from their front only (lead G-14 2026-11-12, owner F10 07-00-11, 07-10-13, 07-01-12,
## 06-51-31: the backs of the City's painted-view and wooden-panel walls, and of a Citadel tube wall). The producer renames
## source_wall to wall only on L12/L14/L17/L20; on these levels the faces keep kind source_wall, which the base class drew
## from both sides. Per level; meta lol2_onesided_source_off restores both-sided drawing for an A/B capture.
const ONE_SIDED_SOURCE_AREAS := ["L13_RC", "L16_CA", "L19_BC"]  # L10_DC after Sol has seen the pose sheet (lead 2026-11-12)
var region_visibility: Node
var island_mode := false
var portal_nav: Array = []
var _placement_island: Dictionary = {}
func _ready() -> void:
	area_owners = preload("res://scripts/lol2/area_owner_registry.gd").new()
	var owner_error: String = area_owners.prepare(area_id)
	assert(owner_error.is_empty(), owner_error)
	add_child(area_owners)
	region_blockers_enabled = map_blockers_enabled
	one_sided_source_kind = area_id in ONE_SIDED_SOURCE_AREAS and not get_tree().has_meta("lol2_onesided_source_off")
	# Exported fields are set before _ready, so the per-area sky pack is chosen here (the base reads sky_pack in its _ready).
	sky_pack = SKY_ROOT + area_id + "/"
	preload("res://scripts/lol2/act3_journal_hints.gd").attach(self)
	# Same-height overlap moves (L14 T3): the moved pack replaces the original for every reader of geometry_file.
	geometry_file = preload("res://scripts/lol2/geometry_move.gd").pack_path(area_id, geometry_file)
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
	for i in data.faces.size():
		if area_owners.claims_static(data.faces[i]): excluded_faces[i] = true
	var nav_file: String = preload("res://scripts/lol2/geometry_move.gd").nav_path(area_id, preload("res://scripts/lol2/act2_progression.gd").NAV_ROOT + area_id + ".json")
	if (area_id in EDGE_RULE_AREAS or area_id in REGION_COLLISION_AREAS) and FileAccess.file_exists(nav_file):
		var nav: Variant = JSON.parse_string(FileAccess.get_file_as_string(nav_file))
		if nav is Dictionary and nav.get("regions") is Array:
			nav_regions = nav.regions
			if area_id in EDGE_RULE_AREAS:
				var rule: Dictionary = RegionEdgeRule.classify(data.faces, nav_regions)
				excluded_faces.merge(rule.pass)
				edge_block_keys = rule.block
				edge_rule_counts = rule.counts
			if area_id in REGION_COLLISION_AREAS:
				region_collision_enabled = true
				collision_links = RegionEdgeRule.links(nav_regions)
	pink_plates_on = PinkPlates.enabled(get_tree(), area_id)
	_height_boundary_walls()
	_load_tracker()
	# Portal visibility (region_visibility.gd, DEVIATIONS 2026-11-05): batch static faces per region cluster first.
	var visibility_nav: Array = []
	if area_id in PORTAL_VISIBILITY_AREAS and not get_tree().has_meta("lol2_portal_visibility_off"):
		visibility_nav = preload("res://scripts/lol2/region_visibility.gd").load_regions(area_id)
		if not visibility_nav.is_empty():
			island_mode = area_id in ISLAND_AREAS and not get_tree().has_meta("lol2_portal_islands_off")
			portal_nav = visibility_nav
			region_cluster = preload("res://scripts/lol2/region_visibility.gd").islands(visibility_nav, data.faces) if island_mode else preload("res://scripts/lol2/region_visibility.gd").clusters(visibility_nav)
	if Binder.assets_ready(area_id):
		Binder.claim_moving_floors(self, area_id, data, excluded_faces)
	super._ready()
	if pink_plates_on: pink_plate_tops = PinkPlates.attach(self, data.faces)
	_height_boundary_body(data)
	preload("res://scripts/lol2/act2_visuals.gd").apply(self, area_id)
	if start_override != null:
		data["start_heading_units"] = int(start_override.heading)
		start_selector = int(start_override.selector)
		player.position = start_override.position
	var batched: Dictionary = preload("res://scripts/lol2/prop_billboards.gd").batch(self, data, geometry_file, "MapProps", island_mode)
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
	# Liquids of this area (liquid_drowning.gd, owner 2026-10-31; staged by tools/prepare_liquid_regions.py): L19's guck.
	var liquid_regions: Dictionary = {}
	if preload("res://scripts/lol2/liquid_drowning.gd").assets_ready(area_id):
		liquid_drowning = preload("res://scripts/lol2/liquid_drowning.gd").new()
		add_child(liquid_drowning)
		var liquid_error: String = liquid_drowning.setup(self, area_id)
		if not liquid_error.is_empty(): push_warning("act2_map %s: liquids not hosted (%s)" % [area_id, liquid_error])
		else:
			for region in liquid_drowning.regions: liquid_regions[int(region.id)] = true
	# A liquid region is a hazard the player may enter, not a wall: its bit0 blocker edges are left out (BK03 2026-11-09).
	if region_blockers_enabled: preview_blockers = preload("res://scripts/lol2/region_blockers.gd").attach(self, player, area_id, Vector3.ZERO, liquid_regions)
	# Thin hanging regions no body can stand in (under 16 high) are solid to the player (owner F10 2026-11-15, L10 yard).
	if region_blockers_enabled and player is CharacterBody3D: thin_region_blocks = preload("res://scripts/lol2/thin_region_blocks.gd").attach(self, player, area_id, geometry_file)
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
	elif not Binder.native_missing(area_id).is_empty():
		var missing: String = Binder.native_missing(area_id)
		push_error("act2_map: " + missing)
		save_feedback(missing)
		if is_instance_valid(interface_hud): interface_hud.save_notice_remaining = 30.0

	act2_creatures = preload("res://scripts/lol2/act2_creatures.gd").attach(self, area_id)
	preload("res://scripts/lol2/debug_kill.gd").attach(self)

	act2_items = preload("res://scripts/lol2/act2_world_items.gd").attach(self, area_id)
	preload("res://scripts/lol2/act2_chargers.gd").attach(self, area_id)
	preload("res://scripts/lol2/game_session.gd").for_tree(get_tree()).apply_pending(self)
	area_owners.attach_all(self, area_id, "early")
	if area_id=="L12_CM":
		# BJ14 G2: first arrival in the Claw Mountains says where to go (Journal note once, and one screen line).
		get_tree().create_timer(0.5).timeout.connect(func(): if is_inside_tree() and preload("res://scripts/lol2/my_journal.gd").discover(self, "l12_claw_arrival"): save_feedback("The Claw Mountains. Climb northeast out of the gulch."))
		# Lead 2026-11-15: back from the Citadel with the Dreamstone, the screen and the Journal say where it goes.
		if arrived_by_level_change: get_tree().create_timer(0.6).timeout.connect(_dreamstone_home_line)
	if not region_cluster.is_empty() and progression != null:
		region_visibility = preload("res://scripts/lol2/region_visibility.gd").new()
		add_child(region_visibility)
		if island_mode and area_id in ISLAND_SKY_AREAS:
			# The black void and the panorama through roofless regions' native ceilings (island_sky_ceilings.gd).
			var native: Dictionary = preload("res://scripts/lol2/region_visibility.gd").load_native(area_id)
			var ceilings: Array = native.get("region_ceiling", [])
			preload("res://scripts/lol2/island_sky_ceilings.gd").attach(self, visibility_nav, data.faces, ceilings, region_cluster)
		if get_tree().has_meta("lol2_portal_overlap_off"): region_visibility.overlap_edges = false
		# The faces go to every portal level so overlap joins can check walls; the island opening classification stays islands-only.
		region_visibility.setup(self, area_id, visibility_nav, region_cluster, cluster_meshes, data.faces, preload("res://scripts/lol2/region_visibility.gd").load_potential(area_id) if island_mode else {}, island_mode)
	area_owners.attach_all(self, area_id, "late")
	if sector_lighting != null:
		sector_lighting.apply(self)
		sector_lighting.set_enabled(sector_light_enabled)
	body_fit = preload("res://scripts/lol2/act2_body_fit.gd").new()
	body_fit.setup(self)

const PinkPlates := preload("res://scripts/lol2/l13_pink_plates.gd")
var pink_plates_on := false
var pink_plate_tops := 0
func include_collision_face(face: Dictionary) -> bool:
	if is_instance_valid(area_owners) and area_owners.claims_collision(face): return false
	if pink_plates_on and PinkPlates.is_plate(face): return false   # top faces only, own body (l13_pink_plates.gd)
	# Keep the terrain byte-identical with the L10 boundary adapter off/on. Even
	# distant added triangles can change Godot's contacts at an unrelated stair.
	if area_id == "L10_DC" and str(face.get("kind", "")) == "source_wall": return false
	if bool(face.get("source_wall", false)): return region_edge_blocks(face)
	return super.include_collision_face(face)

## The region-edge rule: a source wall with no walkable region beyond it is the original's impassable side.
## G-05 class B (lead 2026-11-12, owner F10 06-24-14 Temple and 06-39-44 Claw: walked through drawn walls). Sol's shared
## producer tools/prepare_boundary_collision.py (2695ec6, native neighbours and interpolated floor/ceiling spans) gives per
## level: block_face_keys, whole drawn wall records the body may not cross (null neighbour with no usable passage beyond, or
## a lower band wholly below a linked edge's raised opening), fed to the existing boundary adapter (region_edge_blocks); and
## collision_faces, the part of a wall record that lies below a linked edge's opening (L14 r36 e3: 8259/8261 below 55, the
## native 55..75 slot stays open), collision only, never the whole crossing face. Meta lol2_height_boundary_off = before.
## NARROW (lead 2026-11-12): the packets hold only the walls the owner's reports name (L14 the pocket edge 13912.., L12 6181,
## 7371). Sol's wide census closed 73 walls across ground the owner walked (classB/ALL_TRACE_REPLAY_20261112.md); it
## returns only after passing AI_COMMS/opus_lane/tools/trace_replay_boundary.py.
const HEIGHT_BOUNDARY_AREAS := ["L10_DC", "L12_CM", "L14_HT", "L16_CA"]
const HEIGHT_BOUNDARY_ROOT := "res://scripts/lol2/height_boundary/"
var height_boundary_polygons: Array = []
var height_boundary_keys: Dictionary = {}
const HeightBoundary=preload("res://scripts/lol2/height_boundary_collision.gd")
func _height_boundary_walls() -> void:
	if area_id not in HEIGHT_BOUNDARY_AREAS or get_tree().has_meta("lol2_height_boundary_off"):return
	if area_id=="L10_DC" and not boundary_walls_enabled:return
	var packet:=HeightBoundary.load_packet(area_id,geometry_file)
	if packet.is_empty():return
	height_boundary_keys=HeightBoundary.keys(packet)
	height_boundary_polygons=packet.get("collision_faces",[])
	edge_rule_counts["height_boundary"]=packet.get("counts",{})
	if area_id=="L10_DC":edge_rule_counts["l10_void_walls"]=int(packet.get("counts",{}).get("selected_faces",0))
func _height_boundary_admits(index:int,face:Dictionary)->bool:
	return include_static_face(face) and not excluded_faces.has(index) and not retired_faces.has(index) and not skipped_faces.has(index) and not area_owners.claims_collision(face)
func _height_boundary_body(data:Dictionary)->void:
	HeightBoundary.attach(self,data,height_boundary_keys,height_boundary_polygons,_height_boundary_admits)

func region_edge_blocks(face: Dictionary) -> bool:
	if area_id=="L10_DC":return height_boundary_keys.has(RegionEdgeRule.face_key(face))
	return not edge_block_keys.is_empty() and edge_block_keys.has(RegionEdgeRule.face_key(face))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_region_collision_tick()

## The player's region for the collision, tracked like the original mover: the body stays in its region while inside
## its polygon, leaves only into a linked neighbour, and is placed afresh (nearest floor) only when it lies in neither -
## so a second layout crossing the player's corridor at the same height never captures the body.
func _collision_region_at(point: Vector3) -> int:
	var last := last_collision_region
	if last >= 0 and _inside_nav_region(last, point): return last
	if last >= 0:
		for neighbour in collision_links.get(last, {}):
			if _inside_nav_region(int(neighbour), point): return int(neighbour)
	return progression.region_at(point)

func _inside_nav_region(index: int, point: Vector3) -> bool:
	if index < 0 or index >= nav_regions.size(): return false
	var quad: Array = nav_regions[index][0]
	if quad.is_empty(): return false
	var polygon := PackedVector2Array()
	for v in quad: polygon.append(Vector2(float(v[0]), float(v[1])))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)

## Enables the collision of the regions within COLLISION_HOPS of the player's region when that region changes. Runs from
## _physics_process and from move_grounded, so the harness-driven walks (scene physics off) keep the set current too.
func _region_collision_tick(force: bool = false) -> void:
	if not region_collision_enabled or progression == null or region_collision_shapes.is_empty(): return
	var here: int = _collision_region_at(player.global_position)
	if here < 0 or (here == last_collision_region and not force): return
	last_collision_region = here
	var active: Dictionary = {here: 0}
	var queue: Array = [here]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var depth: int = int(active[current])
		if depth >= COLLISION_HOPS: continue
		for neighbour in collision_links.get(current, {}):
			if not active.has(neighbour):
				active[neighbour] = depth + 1
				queue.append(neighbour)
	active_collision_regions = active.size()
	set_active_regions(active)
	if OS.has_environment("LOL2_REGION_DEBUG"): print("REGION COLLISION at ", player.global_position, " region ", here, " active ", active.size())

func apply_save(state: Variant) -> String:
	var error := preload("res://scripts/lol2/act2_save.gd").validate(state, area_save_format)
	if not error.is_empty(): return error
	# Reset/replay world floor geometry before the parent's saved player pose is
	# applied. Loading never carries Luther through the old world's floor delta.
	if area_id=="L19_BC" and is_instance_valid(progression): progression.restore_floor_checkpoint(state.get("floor_motion", {}))
	error = super.apply_save(state)
	# The saved tracked region keeps the body on its own layer where two region layouts overlap (the L17 cave throat:
	# a fresh nearest-floor pick there can land on 1236 over 562); it is used only while the body still lies inside it.
	var saved: int = int(state.player.get("region", -1)) if state.player.get("region") is float or state.player.get("region") is int else -1
	# A save taken before a geometry move, standing in a moved region, follows its floor (L14 T3: the tunnel is 100 lower).
	var move_spec: Dictionary = preload("res://scripts/lol2/geometry_move.gd").spec(area_id)
	# Only a body that was inside the region's original space is carried; one standing on top of it stays and re-picks.
	var GM = preload("res://scripts/lol2/geometry_move.gd")
	if saved >= 0 and not move_spec.is_empty() and state.player.get("geometry_move") != str(move_spec.outputs.pack):
		var p0 := player.global_position
		if GM.inside_original(area_id, saved, p0.x, p0.z, p0.y - TRACKER_FEET, move_spec):
			player.global_position.y += GM.delta(area_id, saved, p0.x, p0.z, move_spec)
		else:
			saved = -1
	elif saved < 0 and not move_spec.is_empty() and move_spec.get("carry_bands") is Dictionary and not (move_spec.carry_bands as Dictionary).is_empty() and state.player.get("geometry_move") != str(move_spec.outputs.pack):
		# Hosts that save no region (L10): carried only when the saved feet stood on a moved region's original floor and
		# under anything above it in plan (the yard over the Emperor tomb is never carried) - the T3 lesson.
		var p1 := player.global_position
		var feet := p1.y - TRACKER_FEET
		for key in move_spec.carry_bands:
			var band: Array = move_spec.carry_bands[key]
			var corners: Array = move_spec.corner_quads.get(str(key), [])
			var plan := PackedVector2Array()
			for c in corners: plan.append(Vector2(float(c[0]), float(c[1])))
			if plan.size() < 3 or not Geometry2D.is_point_in_polygon(Vector2(p1.x, p1.z), plan): continue
			if feet < float(band[0]) or feet >= float(band[1]) or not GM.inside_original(area_id, int(key), p1.x, p1.z, feet, move_spec): continue
			player.global_position.y += GM.delta(area_id, int(key), p1.x, p1.z, move_spec)
			break
	last_collision_region = saved if saved >= 0 and _inside_nav_region(saved, player.global_position) else -2
	_region_collision_tick(true)
	if tracker_on:
		# Re-pick on load: the saved tracked region holds only while the body still stands inside its quad.
		tracked_region = saved if saved >= 0 and _tracker_inside(saved, player.global_position) else _tracker_pick(player.global_position)
		tracker_last = player.global_position
		if tracked_region >= 0: last_collision_region = tracked_region
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty() and is_instance_valid(progression) and progression.has_method("restore_struck"): error = progression.restore_struck()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	if error.is_empty() and is_instance_valid(area_owners): error = area_owners.restore_all("load")
	# Load rule (load_region_rule.gd, DEVIATIONS row): the region is set without its entry event, then re-armed.
	if error.is_empty(): preload("res://scripts/lol2/load_region_rule.gd").apply(self)
	return error

func apply_area_handoff(state: Variant) -> String:
	if not state is Dictionary: return "Invalid area handoff."
	var error := preload("res://scripts/lol2/act2_save.gd").quests_error(state.get("quests"))
	if not error.is_empty(): return error
	if state.get("inventory", {}).get("collected", []).size() + state.get("quests", {}).get("act2_items", {}).get("carried", []).size() > 64: return "Inventory exceeds capacity."
	error = super.apply_area_handoff(state)
	if error.is_empty() and is_instance_valid(act2_creatures): error = act2_creatures.restore_from_quests()
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	if error.is_empty() and is_instance_valid(area_owners): error = area_owners.restore_all("arrival")
	return error
func _quicksave_unrecorded(path: String = "") -> String:
	return preload("res://scripts/lol2/act2_save.gd").save_host(self, path)
func _quickload_unrecorded(path: String = "") -> String:
	return preload("res://scripts/lol2/act2_save.gd").load_host(self, path)

func inventory_state() -> Dictionary:
	preload("res://scripts/lol2/act2_items_catalog.gd").sync(self)
	var result := super.inventory_state()
	result.collected = result.collected.filter(func(id): return not preload("res://scripts/lol2/act2_items_catalog.gd").valid(id) or preload("res://scripts/lol2/act2_items_catalog.gd").saved_in_legacy(self,id))
	return result

func jump_launch_speed(sprint:bool=false)->float:
	if has_node("L12RiverRafts"):return get_node("L12RiverRafts").jump_speed(sprint)
	return super.jump_launch_speed(sprint)

func move_grounded(direction: Vector3,delta: float,sprint: bool=false)->void:
	_region_collision_tick()
	if has_node("L10Fences"):get_node("L10Fences").prepare(direction,sprint)
	body_fit_overlap=body_fit.needs_world_fit() if body_fit != null else false
	if not tracker_on:
		super.move_grounded(direction,delta,sprint); return
	# G-05 edge guard (TRACKER_AREAS): the step happens, then a step the original's region mover would refuse is undone.
	tracker_tick()
	var before := player.global_position
	var from := tracked_region
	super.move_grounded(direction,delta,sprint)
	if from < 0 or tracked_region != from or tracker_last == Vector3.INF: return   # reset or re-pick inside the move
	_tracker_guard(from, before)

# Let the ordinary slide/step and a requested jump resolve a stair before fitting.
# Time is measured in movement delta, so admission does not depend on frame rate.
const BODY_FIT_BLOCKED_DELAY := 0.5
var body_fit_blocked_time := 0.0
var body_fit_overlap := false
var body_fit_direction := Vector3.ZERO
var body_fit_progress_origin := Vector3.ZERO
var body_fit_expected_distance := 0.0
var body_fit_jump_in_flight := false
# An existing fit uses its valid world shape for stepping. New fitting still
# gives the ordinary full-form step and jump their first chance.
func _try_grounded_step(motion:Vector3)->bool:
	if body_fit != null and (body_fit.active or body_fit_overlap):return false
	return super._try_grounded_step(motion)

func _move_grounded_body(delta: float) -> void:
	var motion := Vector3(player.velocity.x,0,player.velocity.z) * delta
	var direction:=motion.normalized()
	var start:=player.position
	# The ordinary jump owns its whole flight and landing, not just its ascent.
	# Do not turn that airborne time into a blocked-walking receipt.
	var jump_window := body_fit_jump_in_flight
	if player.is_on_floor():
		body_fit_jump_in_flight = player.velocity.y > 0.0
		jump_window = jump_window or body_fit_jump_in_flight
	if direction.is_zero_approx() or direction.dot(body_fit_direction)<0.95 or jump_window:
		body_fit_blocked_time=0.0;body_fit_expected_distance=0.0;body_fit_progress_origin=start
	body_fit_direction=direction
	# Evaluate net progress over the existing delay. Per-step recovery jitter can move
	# the body sideways/backwards without advancing, and must not continually reset it.
	if body_fit_blocked_time>=BODY_FIT_BLOCKED_DELAY:
		var displacement:=Vector2(start.x-body_fit_progress_origin.x,start.z-body_fit_progress_origin.z)
		var progress:=displacement.dot(Vector2(direction.x,direction.z))
		if progress>=body_fit_expected_distance*0.1:
			body_fit_blocked_time=0.0;body_fit_expected_distance=0.0;body_fit_progress_origin=start
	var allow_fit:bool=body_fit != null and (body_fit.active or body_fit_overlap or (body_fit_blocked_time>=BODY_FIT_BLOCKED_DELAY and player.is_on_floor() and player.velocity.y<=0.0))
	var fit: Dictionary = body_fit.begin(direction,motion.length(),allow_fit) if body_fit != null else {}
	if body_fit != null and body_fit.active and player.velocity.y<=0.0 and super._try_grounded_step(motion):
		player.velocity.x=0.0;player.velocity.z=0.0
	super._move_grounded_body(delta)
	if not fit.is_empty():body_fit.finish(fit)
	if not motion.is_zero_approx():
		body_fit_blocked_time+=delta
		body_fit_expected_distance+=motion.length()
	else:
		body_fit_blocked_time=0.0;body_fit_expected_distance=0.0;body_fit_progress_origin=player.position

func _jump_input_active()->bool:
	return super._jump_input_active() or (DisplayServer.get_name()=="headless" and is_instance_valid(starting_magic) and starting_magic.interface_request)

func use_inventory_item(id:String)->bool:
	if id==preload("res://scripts/lol2/l12_citadel_state.gd").PICTURE and has_node("L12Citadel"):return get_node("L12Citadel").arm(id)
	return super.use_inventory_item(id)

func area_snapshot() -> Dictionary:
	return preload("res://scripts/lol2/act2_save.gd").snapshot_host(self)

## G-05 region tracker and edge guard (lead 2026-11-12, plan on the board; ledger 0641). The original moves the player by
## region: the tracked region is kept while the plan point stays inside its quad; a step that leaves it goes into the first
## of its four neighbours (slot order) whose quad holds the point, and only if that neighbour's floor is not more than a
## step above the FEET (drops always allowed); otherwise the step does not happen. On TRACKER_AREAS the port applies that
## rule on top of its own collision: a refused step slides along the crossed edge like a wall. The tracked region also
## starts portal drawing (region_visibility). It is re-picked (highest floor at or below the feet under the point) after a
## level or save load, fall recovery, a relocation, or when the feet are far from the tracked floor (a fall, a lift).
## Tables: scripts/lol2/region_mover/AREA.json (tools/prepare_region_mover.py). Meta lol2_region_tracker_off = off.
const TRACKER_AREAS := ["L14_HT"]
const TRACKER_STEP := 48.0
const TRACKER_FEET := 32.0      # the body origin stands 32 above the feet
const TRACKER_FAR := 64.0       # feet this far below the tracked floor (a fall), or above it on a floor (a lift): re-pick
const TRACKER_HOPS := 3          # neighbour hops one step may take (slivers, corner cuts); trace_replay_tracker.py --hops
const TRACKER_JUMP := 150.0     # a move longer than this in one tick is a relocation: re-pick
var tracker_on := false
var tracker_table: Array = []
var tracker_overlaps: Dictionary = {}   # regions where two layouts overlap at the same height (the guard's scope)
var tracked_region := -1
var tracker_last := Vector3.INF
var tracker_refused := 0

func _load_tracker() -> void:
	tracker_on = false; tracker_table = []; tracked_region = -1; tracker_last = Vector3.INF
	if not area_id in TRACKER_AREAS or get_tree().has_meta("lol2_region_tracker_off"): return
	var path: String = preload("res://scripts/lol2/geometry_move.gd").mover_path(area_id, "res://scripts/lol2/region_mover/%s.json" % area_id)
	if not FileAccess.file_exists(path):
		push_error("Region tracker: %s is listed but %s is missing" % [area_id, path]); return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("area") != area_id or not data.get("regions") is Array:
		push_error("Region tracker: %s is not a table for %s" % [path, area_id]); return
	if not data.get("overlap_regions") is Array:
		push_error("Region tracker: %s has no overlap_regions (regenerate with tools/prepare_region_mover.py)" % path); return
	tracker_table = data.regions
	tracker_overlaps = {}
	for r in data.overlap_regions: tracker_overlaps[int(r)] = true
	tracker_on = true

func _tracker_inside(index: int, point: Vector3) -> bool:
	if index < 0 or index >= tracker_table.size(): return false
	var quad: Array = tracker_table[index][0]
	if quad.size() != 4: return false
	var polygon := PackedVector2Array()
	for v in quad: polygon.append(Vector2(float(v[0]), float(v[1])))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)

## Floor height of a region at a plan point (its four corner heights over triangles 0,1,2 and 0,2,3, as the producer).
func _tracker_floor(index: int, point: Vector3) -> float:
	var row: Array = tracker_table[index]
	var quad: Array = row[0]
	var corners: Array = row[5] if row.size() > 5 else []
	if corners.size() != 4 or quad.size() != 4: return float(row[3])
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var a := Vector2(quad[tri[0]][0], quad[tri[0]][1]); var b := Vector2(quad[tri[1]][0], quad[tri[1]][1]); var c := Vector2(quad[tri[2]][0], quad[tri[2]][1])
		var det := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(det) < 1e-9: continue
		var u := ((b.y - c.y) * (point.x - c.x) + (c.x - b.x) * (point.z - c.y)) / det
		var v := ((c.y - a.y) * (point.x - c.x) + (a.x - c.x) * (point.z - c.y)) / det
		var w := 1.0 - u - v
		if u >= -1e-4 and v >= -1e-4 and w >= -1e-4:
			return u * float(corners[tri[0]]) + v * float(corners[tri[1]]) + w * float(corners[tri[2]])
	return float(corners.min())

## Fresh pick: the highest floor at or below the feet (plus a step) among the regions whose quad holds the point.
func _tracker_pick(point: Vector3) -> int:
	var feet := point.y - TRACKER_FEET
	var best := -1
	var best_floor := -INF
	for index in tracker_table.size():
		var row: Array = tracker_table[index]
		if int(row[1]) & 0x80 or (row[0] as Array).size() != 4: continue
		if not _tracker_inside(index, point): continue
		var f := _tracker_floor(index, point)
		if f <= feet + TRACKER_STEP and f > best_floor: best = index; best_floor = f
	return best

func tracker_tick() -> void:
	if not tracker_on or not is_instance_valid(player): return
	var p := player.global_position
	var moved: bool = tracker_last != Vector3.INF and Vector2(p.x - tracker_last.x, p.z - tracker_last.z).length() > TRACKER_JUMP
	var stale := tracked_region < 0 or moved or not _tracker_inside(tracked_region, p)
	if not stale:
		var f := _tracker_floor(tracked_region, p)
		var feet := p.y - TRACKER_FEET
		stale = feet < f - TRACKER_FAR or (player.is_on_floor() and feet > f + TRACKER_FAR)
	if stale: tracked_region = _tracker_pick(p)
	tracker_last = p
	if tracked_region >= 0: last_collision_region = tracked_region

## The region portal drawing starts from: the tracked one while the camera stands in its quad (a free camera, a render
## tool's pose camera, falls back to the camera's own region).
func tracked_region_for(camera_position: Vector3) -> int:
	if not tracker_on or tracked_region < 0 or not _tracker_inside(tracked_region, camera_position): return -1
	return tracked_region

## Where a step leaving region `from` lands through the neighbour chain: breadth first in slot order, up to TRACKER_HOPS
## hops through neighbours the step crosses (a frame's step can pass a sliver region, 943 is 3 units deep, or cut a
## corner into a neighbour's neighbour), each no more than a step above the feet. The first region holding the end
## point decides: its index when its floor is <= feet + step (drops allowed), -2 when higher; -1 when no chain reaches
## it (a null edge: the original's mover refuses).
func _tracker_step(from: int, a: Vector3, b: Vector3, feet: float) -> int:
	var frontier: Array[int] = [from]
	var seen := {from: true}
	for hop in TRACKER_HOPS:
		var following: Array[int] = []
		for r in frontier:
			for n in tracker_table[r][2]:
				var nb := int(n)
				if nb < 0 or seen.has(nb): continue
				seen[nb] = true
				if _tracker_inside(nb, b): return nb if _tracker_live(nb) or _tracker_floor(nb, b) <= feet + TRACKER_STEP else -2
				if float(tracker_table[nb][3]) <= feet + TRACKER_STEP and _tracker_crossed(nb, a, b): following.append(nb)
		frontier = following
		if frontier.is_empty(): break
	return -1

func _tracker_crossed(index: int, a: Vector3, b: Vector3) -> bool:
	if _tracker_inside(index, a): return true
	var quad: Array = tracker_table[index][0]
	var a2 := Vector2(a.x, a.z); var b2 := Vector2(b.x, b.z)
	for e in 4:
		if Geometry2D.segment_intersects_segment(a2, b2, Vector2(quad[e][0], quad[e][1]), Vector2(quad[(e + 1) % 4][0], quad[(e + 1) % 4][1])) != null: return true
	return false

## A region whose floor progression has moved or lifted onto a deck (opcode 196 floor_motion / floor_decks): its table
## height is stale, so the physics bodies decide steps onto or off it.
func _tracker_live(index: int) -> bool:
	if not is_instance_valid(progression): return false
	for key in ["floor_decks", "floor_motion"]:
		var moved: Variant = progression.get(key)
		if moved is Dictionary and (moved as Dictionary).has(index): return true
	return false

func _tracker_guard(from: int, before: Vector3) -> void:
	var after := player.global_position
	if _tracker_inside(from, after): return
	# Only a step taken on the tracked region's own static floor is judged: on a mover top, a raised or lowered deck,
	# or in the air above/below that floor by more than a step, the bodies and physics decide (the table is stale there).
	# Lead decision (A): the guard acts only on steps out of a region where two layouts overlap at the same height.
	if not tracker_overlaps.has(from): return
	if _tracker_live(from) or absf((before.y - TRACKER_FEET) - _tracker_floor(from, before)) > TRACKER_STEP: return
	var next := _tracker_step(from, before, after, after.y - TRACKER_FEET)
	if next >= 0:
		tracked_region = next; last_collision_region = next; tracker_last = after
		return
	# Refused: slide along the crossed edge of the tracked quad like a wall (keeps the sideways motion, no jitter).
	tracker_refused += 1
	if OS.has_environment("LOL2_TRACKER_LOG"):
		print("TRACKER REFUSED from %d at (%.1f, %.1f, %.1f) to %d" % [from, after.x, after.y, after.z, _tracker_step(from, before, after, after.y - TRACKER_FEET)])
	var quad: Array = tracker_table[from][0]
	var a2 := Vector2(before.x, before.z); var b2 := Vector2(after.x, after.z)
	var slid := a2
	for e in 4:
		var p0 := Vector2(quad[e][0], quad[e][1]); var p1 := Vector2(quad[(e + 1) % 4][0], quad[(e + 1) % 4][1])
		if Geometry2D.segment_intersects_segment(a2, b2, p0, p1) == null: continue
		var along := (p1 - p0).normalized()
		var candidate := a2 + along * (b2 - a2).dot(along)
		var inward := Vector2(-along.y, along.x)
		if inward.dot((Vector2(quad[(e + 2) % 4][0], quad[(e + 2) % 4][1]) - p0)) < 0: inward = -inward
		candidate += inward * 0.05
		if _tracker_inside(from, Vector3(candidate.x, 0, candidate.y)): slid = candidate
		var v := Vector2(player.velocity.x, player.velocity.z)
		var vs := along * v.dot(along)
		player.velocity.x = vs.x; player.velocity.z = vs.y
		break
	player.global_position = Vector3(slid.x, after.y, slid.y)
	tracker_last = player.global_position

func reset_position() -> void:
	super.reset_position()
	tracked_region = -1; tracker_last = Vector3.INF

## A fall into the void puts Luther back at the level's arrival; the City says so (lead 2026-11-16, Grok 08:25Z: he woke
## at the arrival lift with nothing said). Row 0673.
const CITY_FALL_LINE := "You fall and wake at the arrival lift."
const CITY_FALL_LINE_OTHER := "You fall and wake where you came into the City."
func _after_fall() -> void:
	if area_id == "L16_CA": save_feedback(CITY_FALL_LINE if start_selector == 1 else CITY_FALL_LINE_OTHER)

## Serialize the generic pilot through the same checkpoint boundary used by saves and map handoffs.
func _sync_exit_checkpoint() -> void:
	super._sync_exit_checkpoint()
	var generic:Node=get_node_or_null("GenericObjects")
	if generic!=null:generic.sync()

## Arrival in the Claw Mountains carrying the Dreamstone before the temple door has it: Journal note (once) and one screen line.
func _dreamstone_home_line() -> void:
	if not is_inside_tree() or not preload("res://scripts/lol2/l13_journal_hints.gd").dreamstone_home_open(self): return
	preload("res://scripts/lol2/my_journal.gd").discover(self, "l13_dreamstone_home")
	save_feedback(DREAMSTONE_HOME_LINE)
