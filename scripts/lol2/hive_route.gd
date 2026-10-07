extends Node
## Grounded source polygon transitions for both original entrance pairs.
const META := "lol2_hive_route_handoff"
const SCENES := {"hive":"res://scenes/lol2/hive_review.tscn","jungle":"res://scenes/lol2/jungle_walkthrough.tscn"}
var area := ""
var route: Dictionary
var routes: Array[Dictionary] = []
var armed_regions: Dictionary = {}
var armed := false
var transitioning := false
var last_error := ""
func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_routes/routes.json"))
	route = catalog[area]
	routes.assign([route,catalog[area+"_small"]])
	var tree := get_tree()
	if tree.has_meta(META):
		var transfer = tree.get_meta(META)
		if transfer is Dictionary and transfer.get("destination") == area:
			last_error = get_parent().apply_area_handoff(transfer.state)
			if last_error.is_empty():
				var p = transfer.position
				get_parent().player.position = Vector3(p[0],p[1],p[2])
				get_parent().player.velocity = Vector3.ZERO
				get_parent().player.rotation.y = transfer.yaw
				get_parent().camera.rotation.x = transfer.pitch
				get_parent().start = get_parent().player.position
				get_parent().set_development_mode(false)
				tree.remove_meta(META)
			else: push_error(last_error)
func inside() -> bool:
	return inside_route(route)
func inside_route(candidate: Dictionary) -> bool:
	var p: Vector3 = get_parent().player.position
	var polygon := PackedVector2Array()
	for point in candidate.polygon: polygon.append(Vector2(point[0],point[1]))
	var foot := p.y - preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	var height: float = preload("res://scripts/lol2/player_form_body.gd").HEIGHTS[get_parent().player_form]
	return foot >= candidate.floor - 1.0 and foot + height <= candidate.ceiling + 1.0 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon)
func _physics_process(_delta: float) -> void:
	var parent = get_parent()
	if transitioning or get_tree().current_scene != parent or not parent.ready_for_review: return
	var found := false
	for candidate in routes:
		if not inside_route(candidate):
			armed_regions[int(candidate.region)] = true
		else:
			route = candidate
			found = true
	armed = armed_regions.get(int(route.region),false)
	if not found: return
	if not armed or get_tree().paused or parent.flying or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not parent.player.is_on_floor(): return
	if parent.has_node("Warriors") and not parent.get_node("Warriors").active(): return
	begin_transition()
func begin_transition() -> bool:
	var parent = get_parent()
	if transitioning or get_tree().paused or parent.flying or not armed or not inside() or not parent.player.is_on_floor() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if parent.has_node("Warriors") and not parent.get_node("Warriors").active(): return false
	var state: Dictionary = parent.area_handoff()
	var validator = preload("res://scripts/lol2/jungle_save.gd")
	last_error = validator.validate_inventory(state.get("inventory"))
	if last_error.is_empty(): last_error = validator.Quests.validate(state.get("quests"))
	if not last_error.is_empty(): return false
	var destination: String = SCENES[route.destination]
	if not ResourceLoader.exists(destination):
		last_error = "Destination scene is missing."
		return false
	transitioning = true
	parent.set_physics_process(false)
	finish_transition.call_deferred(state.duplicate(true),destination)
	return true
func finish_transition(state: Dictionary, destination: String) -> void:
	var parent = get_parent()
	var tree := get_tree()
	tree.set_meta(META,{"destination":route.destination,"state":state,"position":route.arrival.duplicate(),"yaw":parent.player.rotation.y,"pitch":parent.camera.rotation.x})
	var error := tree.change_scene_to_file(destination)
	if error != OK:
		tree.remove_meta(META)
		transitioning = false
		last_error = "Could not load the destination (%d)." % error
		parent.set_physics_process(true)
		push_error(last_error)
