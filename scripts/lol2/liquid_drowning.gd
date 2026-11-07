extends Node
## Drowning in the water regions of an area (owner 2026-10-31: Luther CAN drown in the Cave river, and the LIZARD form
## drowns in water everywhere; Classic behaviour, not an adapter). Water regions come from assets/lol2/generated/liquid/
## AREA.json (tools/prepare_liquid_regions.py: polygon, floor = bed, surface = bank level). The player's feet stand 32
## units under the body origin (player_form_body.FOOT_OFFSET); a form is SUBMERGED inside a water polygon when
##   Lizard (form 2): its feet are below the surface (any water deeper than where it stands);
##   Human / Beast:   the top of its head (feet + HEIGHTS[form]: 46 / 69) is below the surface.
## Submersion feeds river_drowning_state.gd (the Cave's 12 s clock and message); at the limit the player drowns: health 0
## through the host's starting_magic (the hosts' "fallen" flow: no walking, R / F9 recover) with the drowning notice. The
## Jungle river-dam regions are water only while the dam stands (jungle_river_dam.broken()). The Cave keeps its own
## river query (river_region_query.submerged_form). Surface heights are the bank model until the native bytes are decoded.
const State := preload("res://scripts/lol2/river_drowning_state.gd")
const Form := preload("res://scripts/lol2/player_form_body.gd")
const ROOT := "res://assets/lol2/generated/liquid/"
const CELL := 256.0
var area := ""
var host: Node3D
var regions: Array = []
var grid: Dictionary = {}
var drowning := State.new()
var dam_regions: Dictionary = {}
var last_region := -1
var notice_shown := false
var overlay: Control

static func path_for(which: String) -> String: return ROOT + which + ".json"
static func assets_ready(which: String) -> bool: return FileAccess.file_exists(path_for(which))

func setup(owner: Node3D, which: String) -> String:
	if not assets_ready(which): return "Liquid regions of %s are not staged." % which
	host = owner
	area = which
	name = "LiquidDrowning"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path_for(which)))
	if not data is Dictionary or data.get("version") != 1 or not data.get("regions") is Array: return "Invalid liquid pack for %s." % which
	for row in data.regions:
		var polygon := PackedVector2Array()
		for p in row.polygon: polygon.append(Vector2(float(p[0]), float(p[1])))
		var region := {"id": int(row.region), "polygon": polygon, "floor": float(row.floor), "surface": float(row.surface), "bit0": bool(row.bit0)}
		var index := regions.size()
		regions.append(region)
		var box := Rect2(polygon[0], Vector2.ZERO)
		for p in polygon: box = box.expand(p)
		for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
			for y in range(floori(box.position.y / CELL), floori(box.end.y / CELL) + 1):
				var key := Vector2i(x, y)
				if not grid.has(key): grid[key] = []
				grid[key].append(index)
	if host.get("river_dam") != null and preload("res://scripts/lol2/jungle_river_dam.gd").assets_ready():
		for id in preload("res://scripts/lol2/jungle_river_dam.gd").dynamic_regions(): dam_regions[int(id)] = true
	var layer := CanvasLayer.new()
	layer.layer = 22
	layer.name = "DrowningOverlayLayer"
	add_child(layer)
	overlay = preload("res://scripts/lol2/drowning_overlay.gd").new() as Control
	layer.add_child(overlay)
	return ""

## The water region under the feet at `origin` (the body origin), or {} — polygon hit with the feet within the water column.
func region_at(origin: Vector3) -> Dictionary:
	var feet := origin.y - Form.FOOT_OFFSET
	var p := Vector2(origin.x, origin.z)
	var best := {}
	var best_dy := INF
	for index in grid.get(Vector2i(floori(p.x / CELL), floori(p.y / CELL)), []):
		var region: Dictionary = regions[index]
		if dam_regions.has(region.id) and _dam_broken(): continue
		if feet < region.floor - 64.0 or feet > region.surface + 64.0: continue
		if not Geometry2D.is_point_in_polygon(p, region.polygon): continue
		var dy := absf(feet - region.floor)
		if dy < best_dy: best = region; best_dy = dy
	return best

## Polygon hit only. A jump can lift the body out of region_at's vertical window and must still count as inside.
func polygon_at(origin: Vector3) -> Dictionary:
	var feet := origin.y - Form.FOOT_OFFSET
	var p := Vector2(origin.x, origin.z)
	var best := {}
	var best_dy := INF
	for index in grid.get(Vector2i(floori(p.x / CELL), floori(p.y / CELL)), []):
		var region: Dictionary = regions[index]
		if dam_regions.has(region.id) and _dam_broken(): continue
		if not Geometry2D.is_point_in_polygon(p, region.polygon): continue
		var dy := absf(feet - float(region.floor))
		if dy < best_dy: best = region; best_dy = dy
	return best

func _under_surface(region: Dictionary, origin: Vector3, form: int) -> bool:
	var feet := origin.y - Form.FOOT_OFFSET
	if form == 2: return feet < float(region.surface)
	return feet + Form.HEIGHTS[clampi(form, 0, 2)] < float(region.surface)

func _dam_broken() -> bool:
	var dam = host.get("river_dam")
	return dam != null and is_instance_valid(dam) and dam.has_method("broken") and dam.broken()

## Submerged at `origin` in `form` (see the header).
func submerged(origin: Vector3, form: int) -> bool:
	var region := region_at(origin)
	last_region = int(region.get("id", -1))
	if region.is_empty(): return false
	var feet := origin.y - Form.FOOT_OFFSET
	if form == 2: return feet < float(region.surface)
	return feet + Form.HEIGHTS[clampi(form, 0, 2)] < float(region.surface)

func running() -> bool:
	if host.get_tree().paused or bool(host.get("flying")): return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	var magic = host.get("starting_magic")
	if magic != null and is_instance_valid(magic) and magic.has_method("world_active") and not magic.world_active(): return false
	return true

func _physics_process(delta: float) -> void:
	if host == null or not is_instance_valid(host.get("player")): return
	tick(delta)

## One drowning step; split out so tests can drive it without the frame clock. `running_override` 1 / 0 replaces the world
## gate (running(): pause, flying, actor locks, the movie/mouse-capture world gate), -1 uses it (play).
func tick(delta: float, running_override: int = -1) -> void:
	var magic = host.get("starting_magic")
	var health: int = int(magic.health()) if magic != null and is_instance_valid(magic) and magic.has_method("health") else 30
	if drowning.dead:
		# R / F9 restored health: the clock resets and the water may be entered again.
		if health > 0:
			drowning.reset()
			notice_shown = false
		_sync_overlay()
		return
	if health <= 0: return
	var origin: Vector3 = host.player.global_position
	var form := int(host.get("player_form"))
	var region := polygon_at(origin)
	var inside := not region.is_empty()
	var under := _under_surface(region, origin, form) if inside else false
	var body := host.player as CharacterBody3D
	var feet := origin.y - Form.FOOT_OFFSET
	var rising := absf(body.velocity.y) > 30.0
	var on_bed := false
	if inside and not rising:
		on_bed = absf(feet - float(region.floor)) <= 2.0
	# is_on_floor stays true until the next move_and_slide, including a test that only lifts the body.
	var standing := not rising and (body.is_on_floor() or on_bed)
	drowning.advance(delta, State.counting(under, inside, not standing), running() if running_override < 0 else running_override == 1)
	_sync_overlay()
	if drowning.dead:
		if magic != null and is_instance_valid(magic) and magic.has_method("set_health"): magic.set_health(0)
		if host.has_method("save_feedback") and not notice_shown:
			host.save_feedback("You drowned. R returns to the checkpoint; F9 loads your save.")
			notice_shown = true

func _sync_overlay() -> void:
	if overlay == null: return
	overlay.sync(drowning.elapsed, State.LIMIT, drowning.active or drowning.dead)
