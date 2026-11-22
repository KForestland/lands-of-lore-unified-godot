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
		var error := preload("res://scripts/lol2/act2_items_catalog.gd").validate(quests.act2_items)
		if not error.is_empty(): return error
	return preload("res://scripts/lol2/area_owner_registry.gd").validate_all_quests(quests)
static func validate(state: Variant, format: String) -> String:
	var error := Legacy.validate(state, format)
	if not error.is_empty(): return error
	error = quests_error(state.quests)
	if not error.is_empty(): return error
	if state.inventory.collected.size() + state.quests.get("act2_items", {}).get("carried", []).size() > 64: return "Inventory exceeds capacity."
	if state.player.has("region"):
		# Optional (BK01 follow-up): the region the region-aware collision tracked for the body when the save was written.
		var region: Variant = state.player.region
		if not (region is int or region is float) or region != int(region) or int(region) < 0 or int(region) > 65535: return "Invalid player region."
	if state.has("floor_motion"):
		if format!="lol2-restoration-map-L19_BC": return "Moving-floor checkpoint belongs to another area."
		error = preload("res://scripts/lol2/act2_floor_checkpoint.gd").error(state.floor_motion)
		if not error.is_empty(): return error
		var area := format.trim_prefix("lol2-restoration-map-")
		var path := "res://assets/lol2/generated/creature_nav/%s.json" % area
		if not FileAccess.file_exists(path): return "Missing moving-floor region data."
		var nav: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not nav is Dictionary or not nav.get("regions") is Array: return "Invalid moving-floor region data."
		for key in state.floor_motion.motions:
			if int(str(key))>=nav.regions.size(): return "Moving-floor region outside this area."
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
	return write_save(path, snapshot_host(host), host.area_save_format)

static func snapshot_host(host: Node) -> Dictionary:
	# Slots and explicit legacy files must run the same pre-packing synchronization.
	host._sync_exit_checkpoint()
	# Dragon/Jungle hosts do not inherit act2_map's generic synchronization.
	# Capture the registered bridge at this common save/handoff boundary too.
	var generic:Node=host.get_node_or_null("GenericObjects")
	if generic!=null:generic.sync()
	if is_instance_valid(host.get("act2_creatures")): host.act2_creatures.sync_quests()
	var inventory: Dictionary = host.inventory_state()
	var quests: Dictionary = preload("res://scripts/lol2/atlas_explored.gd").release(host.quest_state.duplicate(true))
	var player: Dictionary = {"position":[host.player.position.x,host.player.position.y,host.player.position.z],"yaw":wrapf(host.player.rotation.y,-PI,PI),"pitch":host.camera.rotation.x}
	# Region-aware collision hosts (L17/L19) keep the body's tracked region, so a save taken where two region layouts
	# overlap (the L17 cave throat) reloads on the same layer; other hosts write no key and older saves stay valid.
	if (bool(host.get("region_collision_enabled")) or host.get("tracker_on") == true) and int(host.get("last_collision_region")) >= 0: player.region = int(host.get("last_collision_region"))
	# Saved under a geometry move: the position is already in the moved geometry (no carry on load).
	var move: Dictionary = preload("res://scripts/lol2/geometry_move.gd").spec(str(host.get("area_id")))
	if not move.is_empty(): player.geometry_move = str(move.outputs.pack)
	var packet: Dictionary={"format":host.area_save_format,"version":1,"inventory":inventory,"quests":quests,
		"atlas_explored":preload("res://scripts/lol2/atlas_explored.gd").stored(host),
		"player":player}
	if host.area_save_format=="lol2-restoration-map-L19_BC" and is_instance_valid(host.get("progression")): packet.floor_motion=host.progression.floor_checkpoint()
	return packet

static func load_host(host: Node, path: String) -> String:
	if host.get_tree().paused: return "Close the current overlay before loading."
	if path.is_empty(): path = host.area_save_path
	var result := read_save(path, host.area_save_format)
	return result.error if not str(result.error).is_empty() else host.apply_save(result.state)
