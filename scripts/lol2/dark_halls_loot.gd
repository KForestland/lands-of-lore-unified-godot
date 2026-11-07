extends Node
## Dark Halls item-giving controls (scripts/lol2/dark_halls_loot_source.json): E while facing one within reach takes
## its next grant (native event4 use: predicate206 first, 207 second). Uses taken per control are saved in
## quests.dark_halls_loot. Aiming is a modern adapter (reach and facing cone; the native click-on-object hit is not used).
const SOURCE := "res://scripts/lol2/dark_halls_loot_source.json"
const REACH := 110.0
const FACING := 0.75
var host: Node3D
var source: Dictionary = {}

static func assets_ready() -> bool: return FileAccess.file_exists(SOURCE)

func setup(walkthrough: Node3D) -> String:
	name = "DarkHallsLoot"
	host = walkthrough
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary: return "Dark Halls loot source missing."
	source = parsed
	return ""

func taken() -> Dictionary:
	var quests: Dictionary = host.quest_state
	if not quests.get("dark_halls_loot") is Dictionary: quests.dark_halls_loot = {}
	return quests.dark_halls_loot

static func validate(value: Variant, src: Dictionary) -> String:
	if not value is Dictionary: return "Invalid Dark Halls loot."
	for key in value:
		var row: Dictionary = {}
		for c in src.controls:
			if str(int(c.control)) == str(key): row = c
		var n = value[key]
		if row.is_empty() or not (n is int or n is float) or float(n) != floor(float(n)) or int(n) < 0 or int(n) > row.grants.size(): return "Invalid Dark Halls loot."
	return ""

## The control in front of the camera within reach, or {}.
func target() -> Dictionary:
	var cam: Camera3D = host.camera
	var best: Dictionary = {}
	var best_dot := FACING
	for c in source.controls:
		if int(taken().get(str(int(c.control)), 0)) >= c.grants.size(): continue
		var point := Vector3(c.position[0], c.position[1] + 24.0, c.position[2])
		var offset := point - cam.global_position
		if offset.length() > REACH: continue
		var dot := (-cam.global_basis.z).dot(offset.normalized())
		if dot > best_dot: best_dot = dot; best = c
	return best

func take() -> bool:
	if not host.get("carried_collected") is Array or host.flying: return false
	var c := target()
	if c.is_empty(): return false
	var key := str(int(c.control))
	var used := int(taken().get(key, 0))
	var grant: Dictionary = c.grants[used]
	if grant.id in host.carried_collected: taken()[key] = used + 1; return false
	if host.carried_collected.size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED:
		if host.has_method("save_feedback"): host.save_feedback("Inventory full.")
		return false
	host.carried_collected.append(grant.id)
	taken()[key] = used + 1
	if host.has_method("save_feedback"): host.save_feedback(preload("res://scripts/lol2/dark_halls_items.gd").ITEMS[grant.id].label + " taken.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and take():
		get_viewport().set_input_as_handled()
