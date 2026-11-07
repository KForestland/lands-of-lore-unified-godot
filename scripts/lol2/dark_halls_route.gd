extends Node
## Original Jungle pocket <-> Dark Halls level changes (tools/prepare_dark_halls_routes.py), as hive_route.gd:
## grounded polygon admission, armed after the player has been outside the region, inventory/quests handoff.
## Jungle: L4 region3205 -> L7 entry1. Dark Halls: regions 1394/1408-1413 -> L4 entry6, once the host's exits_open()
## (the window puzzle) allows it.
const META := "lol2_dark_halls_route_handoff"
const ROUTES := "res://assets/lol2/generated/dark_halls_routes/routes.json"
const SCENES := {"dark_halls":"res://scenes/lol2/dark_halls.tscn","jungle":"res://scenes/lol2/jungle_walkthrough.tscn"}
const Form = preload("res://scripts/lol2/player_form_body.gd")
var area := ""
var routes: Array[Dictionary] = []
var route: Dictionary = {}
var armed_regions: Dictionary = {}
var transitioning := false
var last_error := ""

static func assets_ready() -> bool:
	return FileAccess.file_exists(ROUTES)

static func catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	return parsed if parsed is Dictionary else {}

func _ready() -> void:
	var data := catalog()
	if data.is_empty(): last_error = "Dark Halls routes missing."; push_error(last_error); return
	routes.assign(data.routes.get(area, []))
	var tree := get_tree()
	if not tree.has_meta(META): return
	var transfer = tree.get_meta(META)
	if not transfer is Dictionary or transfer.get("destination") != area: return
	var parent = get_parent()
	last_error = parent.apply_area_handoff(transfer.state)
	if not last_error.is_empty(): push_error(last_error); return
	var p: Array = transfer.position
	parent.player.position = Vector3(p[0], p[1], p[2])
	parent.player.velocity = Vector3.ZERO
	parent.player.rotation.y = float(transfer.yaw)
	parent.camera.rotation.x = 0.0
	parent.start = parent.player.position
	if parent.has_method("set_development_mode"): parent.set_development_mode(false)
	tree.remove_meta(META)

func inside_route(candidate: Dictionary) -> bool:
	var parent = get_parent()
	var p: Vector3 = parent.player.position
	var polygon := PackedVector2Array()
	for point in candidate.polygon: polygon.append(Vector2(point[0], point[1]))
	var foot := p.y - Form.FOOT_OFFSET
	var form := int(parent.get("player_form")) if parent.get("player_form") != null else 0
	return foot >= float(candidate.floor) - 1.0 and foot + Form.HEIGHTS[form] <= float(candidate.ceiling) + 1.0 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon)

func _physics_process(_delta: float) -> void:
	var parent = get_parent()
	if transitioning or routes.is_empty() or get_tree().current_scene != parent or not parent.ready_for_review: return
	var found := false
	for candidate in routes:
		if not inside_route(candidate): armed_regions[int(candidate.region)] = true
		else:
			route = candidate
			found = true
	if not found or not armed_regions.get(int(route.region), false): return
	if parent.has_method("exits_open") and not parent.exits_open(): return
	if get_tree().paused or parent.flying or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not parent.player.is_on_floor(): return
	begin_transition()

## Workaround (docs/DEVIATIONS.md): the original drops the player into the Jungle pocket (region3191), whose route
## region3205 sits behind a 75-unit step the port's walker cannot climb; MCEL hotspot1 takes that route directly.
func enter_directly() -> bool:
	if transitioning or routes.is_empty(): return false
	route = routes[0]
	return begin_transition()

func begin_transition() -> bool:
	var parent = get_parent()
	if transitioning or route.is_empty(): return false
	var state: Dictionary = parent.area_handoff()
	var validator = preload("res://scripts/lol2/jungle_save.gd")
	last_error = validator.validate_inventory(state.get("inventory"))
	if last_error.is_empty(): last_error = validator.Quests.validate(state.get("quests"))
	if not last_error.is_empty(): return false
	transitioning = true
	parent.set_physics_process(false)
	finish_transition.call_deferred(state.duplicate(true), SCENES[route.destination])
	return true

func finish_transition(state: Dictionary, destination: String) -> void:
	var tree := get_tree()
	# Native heading H (0..65535 a full turn) -> Godot yaw -H*TAU/65536 (dark_halls.gd arrival heading16384 = -PI/2).
	tree.set_meta(META, {"destination": route.destination, "state": state, "position": route.arrival.duplicate(),
		"yaw": -float(route.heading) / 65536.0 * TAU})
	var error := tree.change_scene_to_file(destination)
	if error != OK:
		tree.remove_meta(META)
		transitioning = false
		last_error = "Could not load the destination (%d)." % error
		get_parent().set_physics_process(true)
		push_error(last_error)
