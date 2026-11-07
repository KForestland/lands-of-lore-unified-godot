extends "res://scripts/lol2/jungle_walkthrough.gd"
## Original L7_DH Dark Halls terrain/initial scenery (Act 1, entered from the monastery cellar), creatures, loot, Rix and
## the domed-hall window puzzle; the exits open when the puzzle is done (dark_halls_windows.gd).
const FORMAT := "lol2-restoration-dark-halls"
const DEFAULT_PATH := "user://saves/dark_halls_quicksave.json"
static func arrival_assets_ready() -> bool:
	var path := "res://assets/lol2/generated/dark_halls/area.json"
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("materials") is Dictionary: return false
	for file in data.materials.values():
		if not FileAccess.file_exists(path.get_base_dir()+"/"+file): return false
	return preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready()
## Native bit0 region blockers (jungle_walkthrough.gd's region_blockers_enabled; the parent attaches L4_HJ only with huline_content).
## Off by default (lead, r12r 2026-10-30): the native bit0 blockers ignore regions the original opens by script (the Museum escape run crosses region 1422), so outside the Jungle they wait until dynamic unblocking is hosted.
var dark_halls_blockers_enabled := true  ## native bit0 blockers ON (lead 2026-10-31 blockers-on; own flag so this host can revert alone)
var region_blockers_attached := 0
## Vel's fruit garden (owner report 10-16-31; longplay 81:30 f_00978/f_00979): the round bed is green grass with grown plants in
## the original. The pack binds the bed's 24 floors (every floor that uses material 96 in L7_DH) to the brown soil texture and
## the 12 prop_114 plants to a 25-frame growth sprite whose first frame is empty, so the bed drew bare and brown. Adapter: the
## bed takes the level's own grass material 97 and the plants their grown frame; the growth itself (op14 timers) stays with the
## native host. DEVIATIONS 2026-10-31.
const GARDEN_BED_REGIONS := [1429, 1435, 1439, 1442, 1445, 1446, 1448, 1452, 1455, 1459, 1462, 1465, 1469, 1470, 1471, 1474, 1476, 1478, 1489, 1491, 1493, 1495, 1502, 1504]
const GARDEN_BED_SOIL := "96__front"
const GARDEN_BED_GRASS := "97__front"
const GROWN_PROPS := ["prop_114"]
var garden_bed_faces := 0
var grown_props := 0

func static_face_material(index: int, face: Dictionary) -> String:
	if face.kind == "floor" and face.get("material", "") == GARDEN_BED_SOIL and int(face.region) in GARDEN_BED_REGIONS:
		garden_bed_faces += 1
		return GARDEN_BED_GRASS
	return super.static_face_material(index, face)

func _init() -> void:
	super._init()
	# The Dark Halls walls stay solid (jungle_review.gd source_wall_kind_collides) with or without its bit0 blockers.
	source_wall_kind_collides = true
var area_world_items: Node3D

func _ready() -> void:
	super._ready()
	# Original world-item rows of this level (area_world_items_state.gd "darkhalls"), the Jungle rows' pickup with an area argument.
	if preload("res://scripts/lol2/area_world_items.gd").assets_ready("darkhalls"):
		area_world_items = preload("res://scripts/lol2/area_world_items.gd").new()
		add_child(area_world_items)
		var area_items_error: String = area_world_items.setup(self, "darkhalls")
		if not area_items_error.is_empty(): push_warning(area_items_error)
	# Native player-impassable regions (region bit0, tools/prepare_region_blockers.py), as in the Jungle (L7_DH: 61 regions).
	if dark_halls_blockers_enabled: region_blockers_attached = preload("res://scripts/lol2/region_blockers.gd").attach(self, player, "L7_DH")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
	var prop_materials: Dictionary = {}
	for prop in data.props:
		var key: String = prop.material
		if not prop_materials.has(key):
			var material := StandardMaterial3D.new()
			var image: String = data.materials[key]
			if key in GROWN_PROPS and data.get("animations", {}).has(key):
				image = data.animations[key].frames[-1]
				grown_props += 1
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(geometry_file.get_base_dir()+"/"+image))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			prop_materials[key] = material
		var mesh := QuadMesh.new()
		mesh.size = Vector2(prop.right-prop.left,prop.top-prop.bottom)
		mesh.center_offset = Vector3((prop.left+prop.right)/2.0,(prop.bottom+prop.top)/2.0,0)
		mesh.material = prop_materials[key]
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = Vector3(prop.position[0],prop.position[1],prop.position[2])
		add_child(node)
		prop_nodes[int(prop.record)] = node
	_darken(prop_materials.values())
	_add_scenery_collision()
	_add_creatures()
	if is_instance_valid(creatures):
		rix = preload("res://scripts/lol2/dark_halls_rix.gd").new()
		add_child(rix)
		rix.setup(self)
	if preload("res://scripts/lol2/dark_halls_loot.gd").assets_ready():
		loot = preload("res://scripts/lol2/dark_halls_loot.gd").new()
		add_child(loot)
		var loot_error: String = loot.setup(self)
		if not loot_error.is_empty(): push_error(loot_error)
	if not door_movables.is_empty():
		doors = preload("res://scripts/lol2/dark_halls_doors.gd").new()
		add_child(doors)
		var doors_error: String = doors.setup(self)
		if not doors_error.is_empty(): push_error(doors_error)
	if preload("res://scripts/lol2/dark_halls_windows.gd").assets_ready():
		windows = preload("res://scripts/lol2/dark_halls_windows.gd").new()
		add_child(windows)
		var windows_error: String = windows.setup(self)
		if not windows_error.is_empty(): push_error(windows_error); windows.queue_free(); windows = null
	var route = preload("res://scripts/lol2/dark_halls_route.gd").new()
	route.name = "DarkHallsRoute"
	route.area = "dark_halls"
	add_child(route)
	player.rotation.y = -PI/2
	if get_tree().has_meta("lol2_dark_halls_handoff"):
		var error := apply_area_handoff(get_tree().get_meta("lol2_dark_halls_handoff"))
		if error.is_empty(): get_tree().remove_meta("lol2_dark_halls_handoff")
		else: push_error(error)
	if get_tree().has_meta("lol2_dark_halls_resume"):
		var error := apply_save(get_tree().get_meta("lol2_dark_halls_resume"))
		if error.is_empty(): get_tree().remove_meta("lol2_dark_halls_resume")
		else: push_error(error)

## Modern stand-in for the original depth shade table (docs/DEVIATIONS.md): a dim brown tint on every unshaded surface
## and black distance fog; no sky indoors. Longplay 75:18-85:38 reference.
const TINT := Color(0.55, 0.47, 0.40)
func _darken(extra: Array) -> void:
	for material in materials.values() + extra:
		if material is StandardMaterial3D: material.albedo_color = material.albedo_color * TINT
	for child in get_children():
		if child is WorldEnvironment:
			var environment: Environment = child.environment
			environment.background_mode = Environment.BG_COLOR
			environment.background_color = Color.BLACK
			environment.fog_enabled = true
			environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			environment.fog_light_color = Color.BLACK
			environment.fog_light_energy = 0.0
			environment.fog_density = 0.0028
			environment.fog_sky_affect = 0.0

## Object faces (static assemblies and movables: shelves, frames, doors) are drawn but their faces do not collide;
## solidity comes from the native per-assembly boxes (tools/prepare_static_collision.py --area L7_DH) through the
## shared static_assemblies.gd box builder: unscripted solids at least MIN_SOLID_HEIGHT tall. Scripted ones (crates,
## windows, the Iron Door ...) and the movables (doors, sliding bookcases) stay walk-through (docs/DEVIATIONS.md).
func include_collision_face(face: Dictionary) -> bool:
	return face.kind != "movable"
## Hosted doors (dark_halls_doors.gd) draw their own leaves.
func include_static_face(face: Dictionary) -> bool:
	if face.kind == "movable" and str(face.get("placement_kind", "")) == "movable" and int(face.source_index) in door_movables: return false
	return super.include_static_face(face)
var door_movables: Array = preload("res://scripts/lol2/dark_halls_doors.gd").movables()
const COLLISION := "res://scripts/lol2/static_collision_L7_DH.json"
var solid_bodies: Dictionary = {}
func _add_scenery_collision() -> void:
	if not FileAccess.file_exists(COLLISION): return
	var Assemblies = preload("res://scripts/lol2/static_assemblies.gd")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLISION))
	if not parsed is Dictionary or str(parsed.get("area", "")) != "L7_DH": push_error("Dark Halls collision invalid."); return
	for key in parsed.boxes:
		var b: Dictionary = parsed.boxes[key]
		if bool(b.get("scripted", false)) or int(b.height) < Assemblies.MIN_SOLID_HEIGHT: continue
		var body: StaticBody3D = Assemblies.box_body(int(key), b, Vector3.ZERO)
		if body == null: continue
		add_child(body)
		solid_bodies[int(key)] = body
	if not solid_bodies.is_empty(): player.collision_mask |= Assemblies.SCENERY_LAYER

## Original Rats and SHADEs (tools/prepare_dark_halls_population.py) on the generic scripted creature owner; state in
## quests.dark_halls_population so it travels with saves and the area handoff. Rat look = Museum Rat; SHADE look is an
## adapter (145-pixel figure, hovering slightly).
const CREATURE_CONFIG := {"root":"res://assets/lol2/generated/dark_halls_creatures/","source":"res://scripts/lol2/dark_halls_population_source.json","target_prefix":"darkhalls","fighting_owner":"quest_state","quest_key":"dark_halls_population",
	"names":{"0":"Shade","1":"Rat","2":"Rix"},
	"look":{"0":{"canvas":[320,200],"scale":0.29,"floor_row":175,"radius":12,"height":44},"1":{"canvas":[320,200],"scale":0.21818181818181817,"floor_row":174,"radius":16,"height":32},"2":{"canvas":[640,400],"scale":0.19,"floor_row":335,"radius":15,"height":46}}}
var creatures: Node3D
var loot: Node
var rix: Node
var windows: Node
var doors: Node
var prop_nodes: Dictionary = {}
## The Dark Halls exits open once the window puzzle is done (exit window 246, dark_halls_route.gd).
func exits_open() -> bool:
	return windows == null or not is_instance_valid(windows) or windows.done()
func _add_creatures() -> void:
	if not FileAccess.file_exists(str(CREATURE_CONFIG.root)+"sprites.json"): return
	creatures = preload("res://scripts/lol2/scripted_creature_population.gd").new()
	creatures.name = "DarkHallsCreatures"
	creatures.configure(CREATURE_CONFIG)
	add_child(creatures)
	var error: String = creatures.setup(self)
	if not error.is_empty(): push_error(error)
func apply_save(state: Variant) -> String:
	var error := super.apply_save(state)
	if error.is_empty() and is_instance_valid(creatures): error = creatures.restore_from_quests()
	if error.is_empty() and doors != null and is_instance_valid(doors): doors.restore_from_quests()
	if error.is_empty() and windows != null and is_instance_valid(windows): windows.restore_from_quests()
	return error
func apply_area_handoff(state: Variant) -> String:
	var error := super.apply_area_handoff(state)
	if error.is_empty() and is_instance_valid(creatures): error = creatures.restore_from_quests()
	if error.is_empty() and doors != null and is_instance_valid(doors): doors.restore_from_quests()
	if error.is_empty() and windows != null and is_instance_valid(windows): windows.restore_from_quests()
	return error
