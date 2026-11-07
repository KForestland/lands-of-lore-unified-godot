extends RefCounted
## Act2 hosts retain the legacy packet contract, with validation of every Act2 population
## and a 4MiB guard for ten levels of actors (modern persistence adapter).
const Legacy = preload("res://scripts/lol2/jungle_save.gd")
const Population = preload("res://scripts/lol2/scripted_creature_state.gd")
const MAX_BYTES := 4 * 1024 * 1024
static func quests_error(quests: Variant) -> String:
	if not quests is Dictionary: return "Invalid Act2 quests."
	for key in quests:
		if not str(key).begins_with("act2_creatures_"): continue
		var area := str(key).trim_prefix("act2_creatures_")
		if area not in ["L8_SJ","L9_DR","L10_DC","L12_CM","L13_RC","L14_HT","L16_CA","L17_HC","L19_BC","L20_BB"]: return "Unknown creature area."
		var source := "res://scripts/lol2/act2_populations/%s.json" % area
		var error := Population.validate(quests[key], Population.source(source))
		if not error.is_empty(): return error
	if quests.has("act2_items"):
		return preload("res://scripts/lol2/act2_items_catalog.gd").validate(quests.act2_items)
	return ""
static func validate(state: Variant, format: String) -> String:
	var error := Legacy.validate(state, format)
	if not error.is_empty(): return error
	error = quests_error(state.quests)
	if not error.is_empty(): return error
	if state.inventory.collected.size() + state.quests.get("act2_items", {}).get("carried", []).size() > 64: return "Inventory exceeds capacity."
	return ""
static func read_save(path: String, format: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "No area save found."}
	if file.get_length() > MAX_BYTES: return {"error": "Area save is too large."}
	var state: Variant = JSON.parse_string(file.get_as_text())
	var error := validate(state, format)
	return {"error": error, "state": state if error.is_empty() else {}}
static func write_save(path: String, state: Dictionary, format: String) -> String:
	var error := validate(state, format)
	if not error.is_empty(): return error
	var text := JSON.stringify(state, "", true, true) + "\n"
	if text.to_utf8_buffer().size() > MAX_BYTES: return "Area save is too large."
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return "Cannot create save folder."
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "Cannot write area save."
	file.store_string(text); file.flush()
	var status := file.get_error()
	file.close()
	if status != OK or not read_save(temporary, format).error.is_empty(): return "Could not verify area save."
	if DirAccess.rename_absolute(temporary, path) != OK: return "Cannot replace area save; previous save preserved."
	return ""
static func save_host(host: Node, path: String) -> String:
	if host.get_tree().paused: return "Close the current overlay before saving."
	if host.flying: return "Return to walking mode before saving."
	if path.is_empty(): path = host.area_save_path
	host._sync_exit_checkpoint()
	if is_instance_valid(host.get("act2_creatures")): host.act2_creatures.sync_quests()
	var inventory: Dictionary = host.inventory_state()
	var quests: Dictionary = preload("res://scripts/lol2/atlas_explored.gd").release(host.quest_state.duplicate(true))
	return write_save(path,{"format":host.area_save_format,"version":1,"inventory":inventory,"quests":quests,
		"atlas_explored":preload("res://scripts/lol2/atlas_explored.gd").stored(host),
		"player":{"position":[host.player.position.x,host.player.position.y,host.player.position.z],"yaw":wrapf(host.player.rotation.y,-PI,PI),"pitch":host.camera.rotation.x}}, host.area_save_format)
static func load_host(host: Node, path: String) -> String:
	if host.get_tree().paused: return "Close the current overlay before loading."
	if path.is_empty(): path = host.area_save_path
	var result := read_save(path, host.area_save_format)
	return result.error if not str(result.error).is_empty() else host.apply_save(result.state)
