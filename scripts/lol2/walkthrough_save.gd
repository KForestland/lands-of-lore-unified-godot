extends RefCounted
const Catalog = preload("res://scripts/lol2/item_catalog.gd")

# Restoration-owned format. Original DOS saves are not read or modified.
const FORMAT := "lol2-restoration-walkthrough"
const VERSION := 2
const Collectible = preload("res://scripts/lol2/cave_collectible.gd")
const MAP_ID := "draracle-caverns-v1"
const DEFAULT_PATH := "user://saves/cavern_quicksave.json"
const MAX_BYTES := 65536 # Includes23 independent Roach stat/decision packets.
const DISPLAY_FLAGS := ["lighting", "glow", "props", "roof", "creatures"]

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _vector(value: Variant, limit: float) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not _number(component) or absf(float(component)) > limit:
			return false
	return true

static func validate(value: Variant, checkpoint_count: int) -> String:
	if not value is Dictionary:
		return "Save data must be an object."
	if value.has("magic"):
		var magic := preload("res://scripts/lol2/player_magic_state.gd").restore(value.magic)
		if magic.has("error"): return magic.error
	if value.has("guards"):
		var Guards=preload("res://scripts/lol2/scripted_creature_state.gd")
		var guard_error:=Guards.validate(value.guards,Guards.source("res://scripts/lol2/cave_guard_population_source.json"))
		if not guard_error.is_empty(): return guard_error
		if value.guards.has("audio"):
			var audio_contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_guard_audio_source.json"))
			var audio_error:=preload("res://scripts/lol2/scripted_creature_audio_state.gd").validate(value.guards.audio,Guards.source("res://scripts/lol2/cave_guard_population_source.json").actors,audio_contract)
			if not audio_error.is_empty(): return audio_error
	if value.has("guard_controls"):
		var Controls=preload("res://scripts/lol2/cave_guard_controls_state.gd")
		var controls_error:=Controls.validate(value.guard_controls,Controls.source(),Controls.media())
		if not controls_error.is_empty():return controls_error
	if value.has("captain"):
		var captain_error:=preload("res://scripts/lol2/cave_captain.gd").validate(value.captain)
		if not captain_error.is_empty():return captain_error
	if value.has("lurking_roach"):
		var lurking_error:=preload("res://scripts/lol2/cave_lurking_roach_state.gd").validate(value.lurking_roach)
		if not lurking_error.is_empty(): return lurking_error
	if value.has("eyes"):
		var Eyes=preload("res://scripts/lol2/cave_eyes_state.gd")
		var eyes_error:=Eyes.validate(value.eyes,Eyes.source())
		if not eyes_error.is_empty():return eyes_error
	if value.has("scenic_guard"):
		var Scenic=preload("res://scripts/lol2/cave_scenic_guard_state.gd")
		var scenic_error:=Scenic.validate(value.scenic_guard,Scenic.source())
		if not scenic_error.is_empty():return scenic_error
	if value.has("fighting"):
		var fighting := preload("res://scripts/lol2/player_fighting_transport.gd").restore(value.fighting)
		if fighting.has("error"): return fighting.error
	if value.has("wild_roach"):
		var Wild=preload("res://scripts/lol2/scripted_creature_state.gd")
		var source:=Wild.source("res://scripts/lol2/cave_wild_roach_source.json")
		var wild_error:=Wild.validate(value.wild_roach,source)
		if not wild_error.is_empty(): return wild_error
		if value.wild_roach.has("audio"):
			var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_roach_audio_source.json"))
			var audio_error:=preload("res://scripts/lol2/scripted_creature_audio_state.gd").validate(value.wild_roach.audio,source.actors,contract)
			if not audio_error.is_empty(): return audio_error
	if value.get("format") != FORMAT:
		return "This is not a restoration walkthrough save."
	if not _number(value.get("version")) or (value.version != 1 and value.version != VERSION):
		return "This save version is not supported."
	if value.version == VERSION and not Collectible.validate_ids(value.get("collected")):
		return "Save collected-object state is invalid."
	if value.version == 1 and value.has("collected"):
		return "Version 1 saves cannot contain collected-object state."
	if value.get("map") != MAP_ID:
		return "This save belongs to a different map revision."
	if value.has("player_form") and not preload("res://scripts/lol2/player_form_body.gd").valid(value.player_form):
		return "Save player form is invalid."
	if value.has("curse") and not preload("res://scripts/lol2/player_curse.gd").valid(value.curse,value.get("player_form",0)): return "Invalid curse state."
	if value.has("bridge") and not preload("res://scripts/lol2/cave_bridge_save.gd").validate(value.bridge):
		return "Save bridge state is invalid."
	if value.has("chain_doors") and not preload("res://scripts/lol2/indexed_chain_event.gd").validate_save(value.chain_doors):
		return "Save chain and door state is invalid."
	if value.has("aloe") and not preload("res://scripts/lol2/cave_aloe.gd").validate_ids(value.aloe):
		return "Save Aloe state is invalid."
	if value.has("item_effects"):
		var carried: Array = value.get("aloe",[]).duplicate()
		if value.item_effects is Dictionary and value.item_effects.get("spent") is Array:
			for id in value.item_effects.spent:
				if not id in carried: return "Consumed Aloe was not harvested."
				carried.erase(id)
		var effect_error := preload("res://scripts/lol2/player_item_state.gd").validate(value.item_effects,carried)
		if not effect_error.is_empty(): return effect_error
	if value.has("stalagmites") and not preload("res://scripts/lol2/cave_stalagmite.gd").validate_ids(value.stalagmites):
		return "Save Stalagmite state is invalid."
	if value.has("roach_population_schema"):
		if not preload("res://scripts/lol2/save_value_rules.gd").integer(value.roach_population_schema,1) or value.roach_population_schema!=1 or not value.has("roach_population"): return "Missing cave Roach population packet."
	if value.has("roach_population"):
		var population_error:=preload("res://scripts/lol2/cave_roach_population_state.gd").validate(value.roach_population)
		if not population_error.is_empty(): return population_error
	if value.has("roach") and not preload("res://scripts/lol2/cave_roach.gd").validate(value.roach):
		return "Save cave creature state is invalid."
	var captain_items: Array = []
	if value.has("captain"):
		captain_items = preload("res://scripts/lol2/cave_captain_items.gd").from_grants(value.captain.source.granted)
	var equipped = value.get("equipped_item", "")
	if not equipped is String or (equipped != "" and (Catalog.slot(equipped) != "weapon" or not Catalog.admitted(equipped,"cave") or equipped not in value.get("stalagmites", []) + captain_items)):
		return "Save weapon selection is invalid."
	var armor = value.get("equipped_armor", "")
	if not armor is String or (armor != "" and (Catalog.slot(armor) != "armor" or not Catalog.admitted(armor,"cave") or armor not in captain_items)):
		return "Save armor selection is invalid."
	var checkpoint: Variant = value.get("checkpoint")
	if not _number(checkpoint) or checkpoint != floorf(float(checkpoint)) or checkpoint < 0 or checkpoint >= checkpoint_count:
		return "Save checkpoint is invalid."
	var player: Variant = value.get("player")
	if not player is Dictionary:
		return "Save player state is missing."
	if not _vector(player.get("position"), 1000000.0):
		return "Save position is invalid."
	if not _number(player.get("yaw")) or absf(float(player.yaw)) > PI + 0.00001:
		return "Save heading is invalid."
	if not _vector(player.get("camera_rotation"), TAU):
		return "Save camera rotation is invalid."
	if not player.get("flying") is bool:
		return "Save movement mode is invalid."
	var display: Variant = value.get("display")
	if not display is Dictionary:
		return "Save display settings are missing."
	for key in DISPLAY_FLAGS:
		if not display.get(key) is bool:
			return "Save display setting '%s' is invalid." % key
	return ""

static func read_save(path: String, checkpoint_count: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "No readable quicksave found. Press F5 to save first."}
	if file.get_length() > MAX_BYTES:
		return {"error": "Save file is too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "Save file is damaged (invalid JSON)."}
	var error := validate(parser.data, checkpoint_count)
	if not error.is_empty():
		return {"error": error}
	var state: Dictionary = parser.data
	if state.version == 1:
		state.version = VERSION
		state.collected = []
	return {"error": "", "state": state}

static func write_save(path: String, state: Dictionary, checkpoint_count: int) -> String:
	var error := validate(state, checkpoint_count)
	if not error.is_empty():
		return error
	if state.version != VERSION:
		return "New saves must use the current format version."
	var text := JSON.stringify(state, "  ", true, true) + "\n"
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return "Save data is too large."
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return "Cannot create the save folder."
	# Write a sibling first; a failed write never truncates the previous save.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Cannot write the quicksave."
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return "Could not finish writing the quicksave."
	var reread := read_save(temporary, checkpoint_count)
	if not reread.error.is_empty():
		return "Could not verify the written quicksave."
	if DirAccess.rename_absolute(temporary, path) != OK:
		return "Could not replace the quicksave; the previous save is unchanged."
	return ""
