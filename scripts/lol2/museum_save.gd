extends RefCounted
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
## Restoration-owned museum save, separate from cavern quicksave and DOS files.
const FORMAT := "lol2-restoration-museum"
const DEFAULT_PATH := "user://saves/museum_quicksave.json"
const MAX_BYTES := 65536 # Malformed-file guard only; matches the other area saves.
const SWORD := "museum:item11:Fine_Longsword"
const MAIL := "museum:item10:Mail_Shirt"
const STONES := ["museum:item8:Champion_Stone", "museum:item9:Champion_Stone"]
const CAVERN := "draracle/prop/1108/sample"
const Numbers = preload("res://scripts/lol2/walkthrough_save.gd")

static func within(value: Variant, low: float, high: float) -> bool:
	return Numbers._number(value) and value >= low and value <= high

static func validate(state: Variant) -> String:
	if not state is Dictionary or state.get("format") != FORMAT or not Numbers._number(state.get("version")) or state.get("version") != 1:
		return "Unsupported museum save."
	var checkpoint = state.get("checkpoint")
	if not checkpoint is Dictionary or not Numbers._number(checkpoint.get("version")) or checkpoint.get("version") != 1 or not checkpoint.get("introduction_complete") is bool or checkpoint.get("introduction_complete") != true:
		return "Invalid museum checkpoint."
	if checkpoint.has("magic"):
		var magic := preload("res://scripts/lol2/player_magic_state.gd").restore(checkpoint.magic)
		if magic.has("error"): return magic.error
	if checkpoint.has("fighting"):
		var fighting := preload("res://scripts/lol2/player_fighting_transport.gd").restore(checkpoint.fighting)
		if fighting.has("error"): return fighting.error
	if checkpoint.has("health") and (not within(checkpoint.health,1,30) or checkpoint.health != int(checkpoint.health)): return "Invalid player health."
	if checkpoint.has("player_form") and not preload("res://scripts/lol2/player_form_body.gd").valid(checkpoint.player_form): return "Invalid player form."
	if checkpoint.has("curse") and not preload("res://scripts/lol2/player_curse.gd").valid(checkpoint.curse,checkpoint.get("player_form",0)): return "Invalid curse state."
	var ids = checkpoint.get("collected")
	if not ids is Array or ids.size() > Catalog.MAX_CARRIED: return "Invalid collected items."
	if checkpoint.has("item_effects"):
		var item_error := preload("res://scripts/lol2/player_item_state.gd").validate(checkpoint.item_effects,ids)
		if not item_error.is_empty(): return item_error
	var held = checkpoint.get("hand_item","")
	if not held is String or (held != "" and held not in ids): return "Invalid held exhibit item."
	if checkpoint.has("skeletons"):
		var creature_error := preload("res://scripts/lol2/museum_skeleton_population_state.gd").validate(checkpoint.skeletons)
		if not creature_error.is_empty(): return creature_error
	if checkpoint.has("museum_control96"):
		var control96_error:=preload("res://scripts/lol2/museum_control96_state.gd").validate(checkpoint.museum_control96)
		if not control96_error.is_empty(): return control96_error
		if not checkpoint.has("skeletons") or checkpoint.skeletons.actors["30"].present!=checkpoint.museum_control96.spawned30: return "Inconsistent control96 skeleton."
	if checkpoint.has("museum_control181"):
		var control_error := preload("res://scripts/lol2/museum_broken_thohan.gd").validate_checkpoint(checkpoint.museum_control181)
		if not control_error.is_empty(): return control_error
	var carried_error := Catalog.validate_carried(ids,"museum")
	if not carried_error.is_empty(): return carried_error
	var equipment_error := Catalog.validate_slots(ids,"museum",checkpoint.get("equipped_item"),checkpoint.get("equipped_armor",""))
	if not equipment_error.is_empty(): return equipment_error
	var sword = checkpoint.get("sword")
	if not sword is Dictionary: return "Missing sword state."
	if not sword.get("started") is bool or not sword.get("collected") is bool:
		return "Invalid sword state."
	if sword.collected != (SWORD in ids): return "Inconsistent sword collection."
	if not within(sword.get("elapsed"),0,7.625) or not within(sword.get("idle_elapsed",0),0,0.875):
		return "Invalid sword timing."
	# Prop107 states4/5 (optional; older saves predate them).
	var struck = sword.get("struck", false)
	var replaced = sword.get("replaced", false)
	if not struck is bool or not replaced is bool or (replaced and not struck): return "Invalid sword skeleton state."
	if struck and (not sword.started or sword.elapsed != 7.625): return "Invalid sword skeleton state."
	if checkpoint.has("skeletons") and bool(checkpoint.skeletons.actors["21"].present) != replaced:
		return "Inconsistent sword skeleton replacement."
	var gate = checkpoint.get("gate")
	if not gate is Dictionary or not gate.get("target_open") is bool or not within(gate.get("progress"),0,1):
		return "Invalid gate state."
	if checkpoint.has("hourglass"):
		var hourglass = checkpoint.hourglass
		if not hourglass is Dictionary or not hourglass.get("activated") is bool or not within(hourglass.get("elapsed"),0,5):
			return "Invalid hourglass state."
		if not within(hourglass.get("final_wait",25),0,30): return "Invalid hourglass final timer."
		if not hourglass.get("escaped",false) is bool: return "Invalid escape state."
		if hourglass.get("escaped",false) and (not hourglass.activated or not checkpoint.get("escape_wall") is Dictionary or checkpoint.escape_wall.get("stage") != 4): return "Inconsistent escape state."
		if hourglass.has("stage") != hourglass.has("wait"): return "Incomplete hourglass timer."
		if hourglass.has("stage"):
			if not within(hourglass.stage,-1,3) or hourglass.stage != int(hourglass.stage) or not within(hourglass.wait,0,30):
				return "Invalid hourglass timer."
			if hourglass.activated != (hourglass.stage >= 0): return "Inconsistent hourglass stage."
			if hourglass.stage in [0,1,2] and hourglass.wait < 5.0 - hourglass.elapsed: return "Inconsistent hourglass timing."
			if hourglass.stage in [-1,3] and hourglass.wait != 0: return "Inconsistent hourglass timer."
		if not hourglass.activated and hourglass.elapsed != 0:
			return "Inconsistent hourglass state."
	if checkpoint.has("escape_wall"):
		var wall = checkpoint.escape_wall
		if not wall is Dictionary or not within(wall.get("stage"),0,4) or wall.stage != int(wall.stage) or not within(wall.get("wait"),-1,10):
			return "Invalid escape wall state."
		if wall.stage > 0 and wall.wait != -1: return "Inconsistent escape wall state."
	if checkpoint.has("gallery"):
		var gallery = checkpoint.gallery
		if not gallery is Dictionary or not gallery.get("painting_moved") is bool or not gallery.get("gate_open") is bool or not within(gallery.get("progress"),0,1):
			return "Invalid gallery state."
		var pulled = gallery.get("lever_pulled",gallery.gate_open)
		if not pulled is bool: return "Invalid gallery lever state."
		if (pulled and not gallery.painting_moved) or (gallery.gate_open and not pulled) or (gallery.progress != 0 and not pulled): return "Inconsistent gallery state."
	if checkpoint.has("dragon_door"):
		var door = checkpoint.dragon_door
		if not door is Dictionary or not door.get("opened") is bool or not within(door.get("progress"),0,1): return "Invalid dragon door state."
		if not door.opened and door.progress != 0: return "Inconsistent dragon door state."
	var player = state.get("player")
	if not player is Dictionary or not Numbers._vector(player.get("position"),1000000):
		return "Invalid player position."
	if not within(player.get("yaw"),-PI,PI) or not within(player.get("pitch"),-1.4,1.4):
		return "Invalid player view."
	return ""

static func read_save(path: String = DEFAULT_PATH) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error": "No museum quicksave found. Save with F5 first."}
	if file.get_length() > MAX_BYTES: return {"error": "Museum save is too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"error": "Museum save contains damaged JSON."}
	var error := validate(parser.data)
	return {"error": error, "state": parser.data if error.is_empty() else {}}

static func write_save(path: String, state: Dictionary) -> String:
	var error := validate(state)
	if not error.is_empty(): return error
	var text := JSON.stringify(state,"  ",true,true) + "\n"
	if text.to_utf8_buffer().size() > MAX_BYTES: return "Museum save is too large."
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return "Cannot create save folder."
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "Cannot write museum save."
	file.store_string(text)
	file.flush()
	var status := file.get_error()
	file.close()
	if status != OK or not read_save(temporary).error.is_empty(): return "Could not verify museum save."
	if DirAccess.rename_absolute(temporary,path) != OK: return "Cannot replace museum save; previous save preserved."
	return ""
