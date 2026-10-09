extends RefCounted
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
## Restoration jungle save; isolated from museum and original DOS save files.
const FORMAT := "lol2-restoration-jungle"
const DEFAULT_PATH := "user://saves/jungle_quicksave.json"
const MAX_BYTES := 65536 # Guard only; Hive quest transport (boulders, populations, markers) exceeds16KiB.
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
const Museum = preload("res://scripts/lol2/museum_save.gd")
const Numbers = preload("res://scripts/lol2/walkthrough_save.gd")

static func validate_inventory(state: Variant) -> String:
	if not state is Dictionary: return "Invalid inventory."
	if state.has("magic"):
		var magic := preload("res://scripts/lol2/player_magic_state.gd").restore(state.magic)
		if magic.has("error"): return magic.error
	if state.has("fighting"):
		var fighting := preload("res://scripts/lol2/player_fighting_transport.gd").restore(state.fighting)
		if fighting.has("error"): return fighting.error
	if state.has("health") and (not Museum.within(state.health,1,30) or state.health != int(state.health)): return "Invalid player health."
	if state.has("player_form") and not preload("res://scripts/lol2/player_form_body.gd").valid(state.player_form): return "Invalid player form."
	if state.has("curse") and not preload("res://scripts/lol2/player_curse.gd").valid(state.curse,state.get("player_form",0)): return "Invalid curse state."
	var ids = state.get("collected")
	if not ids is Array or ids.size() > Catalog.MAX_CARRIED: return "Invalid collected items."
	if state.has("item_effects"):
		var item_error := preload("res://scripts/lol2/player_item_state.gd").validate(state.item_effects,ids)
		if not item_error.is_empty(): return item_error
	if state.has("museum_control181"):
		var control_error := preload("res://scripts/lol2/museum_broken_thohan.gd").validate_checkpoint(state.museum_control181)
		if not control_error.is_empty(): return control_error
	var carried_error := Catalog.validate_carried(ids,"jungle")
	if not carried_error.is_empty(): return carried_error
	var equipment_error := Catalog.validate_slots(ids,"jungle",state.get("equipped_item"),state.get("equipped_armor"))
	if not equipment_error.is_empty(): return "Invalid equipment."
	return ""

static func validate(state: Variant, expected_format: String = FORMAT) -> String:
	if not state is Dictionary or state.get("format") != expected_format or not Numbers._number(state.get("version")) or state.get("version") != 1:
		return "Unsupported area save."
	var error := validate_inventory(state.get("inventory"))
	if not error.is_empty(): return error
	error = Quests.validate(state.get("quests",Quests.initial()))
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_item_state.gd").transport_error(state.inventory,state.get("quests",{}))
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_magic_state.gd").transport_error(state.inventory,state.get("quests",{}))
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/player_fighting_transport.gd").transport_error(state.inventory,state.get("quests",{}))
	if not error.is_empty(): return error
	error = preload("res://scripts/lol2/jungle_kelsrick_state.gd").transport_error(state.inventory,state.get("quests",{}))
	if not error.is_empty(): return error
	var player = state.get("player")
	if not player is Dictionary: return "Invalid player."
	var position = player.get("position")
	if not position is Array or position.size() != 3: return "Invalid player position."
	for coordinate in position:
		if not Museum.within(coordinate,-32768,32767): return "Invalid player position."
	if not Museum.within(position[1],-32768 if expected_format=="lol2-restoration-hive" else -2048,32767): return "Invalid player height."
	if not Museum.within(player.get("yaw"),-PI,PI) or not Museum.within(player.get("pitch"),-1.4,1.4): return "Invalid player view."
	return ""

static func read_save(path: String = DEFAULT_PATH, expected_format: String = FORMAT) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error": "No jungle quicksave found. Save with F5 first."}
	if file.get_length() > MAX_BYTES: return {"error": "Jungle save is too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"error": "Jungle save contains damaged JSON."}
	var error := validate(parser.data,expected_format)
	return {"error": error, "state": parser.data if error.is_empty() else {}}

static func write_save(path: String, state: Dictionary, expected_format: String = FORMAT) -> String:
	var error := validate(state,expected_format)
	if not error.is_empty(): return error
	var text := JSON.stringify(state,"  ",true,true) + "\n"
	if text.to_utf8_buffer().size() > MAX_BYTES: return "Jungle save is too large."
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return "Cannot create save folder."
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "Cannot write jungle save."
	file.store_string(text)
	file.flush()
	var status := file.get_error()
	file.close()
	if status != OK or not read_save(temporary,expected_format).error.is_empty(): return "Could not verify jungle save."
	if DirAccess.rename_absolute(temporary,path) != OK: return "Cannot replace jungle save; previous save preserved."
	return ""
