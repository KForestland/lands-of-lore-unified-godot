extends "res://scripts/lol2/jungle_walkthrough.gd"
## Act 2 return to L4 selector7 without changing the shared Act 1 host. Arrival semantics LIKELY.
var start_selector := -1
var arrived_by_level_change := false
var progression: Node = null
var act2_items: Node3D
func _ready() -> void:
	super._ready()
	var tree := get_tree()
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/act2_travel.json"))
	if tree.has_meta("lol2_map_start_selector"):
		start_selector = int(tree.get_meta("lol2_map_start_selector"))
		tree.remove_meta("lol2_map_start_selector")
		for arrival in graph.areas.L4_HJ.arrivals:
			if int(arrival.selector) == start_selector:
				player.position = Vector3(arrival.x, float(arrival.floor_min) + 32.0, -float(arrival.y))
				player.rotation.y = -TAU * float(arrival.heading_units) / 65536.0
	arrived_by_level_change = bool(tree.get_meta("lol2_level_change", false))
	for key in ["lol2_level_change", "lol2_map_preview"]:
		if tree.has_meta(key): tree.remove_meta(key)
	if tree.has_meta("lol2_act2_handoff"):
		var error := apply_area_handoff(tree.get_meta("lol2_act2_handoff"))
		if not error.is_empty(): push_error(error)
		tree.remove_meta("lol2_act2_handoff")

func apply_save(state: Variant) -> String:
	var error := preload("res://scripts/lol2/act2_save.gd").validate(state, area_save_format)
	if not error.is_empty(): return error
	error = super.apply_save(state)
	if error.is_empty(): error = preload("res://scripts/lol2/act2_items_catalog.gd").restore(self)
	return error
func apply_area_handoff(state: Variant) -> String:
	if not state is Dictionary: return "Invalid area handoff."
	var error := preload("res://scripts/lol2/act2_save.gd").quests_error(state.get("quests"))
	if not error.is_empty(): return error
	if state.get("inventory", {}).get("collected", []).size() + state.get("quests", {}).get("act2_items", {}).get("carried", []).size() > 64: return "Inventory exceeds capacity."
	error = super.apply_area_handoff(state)
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
