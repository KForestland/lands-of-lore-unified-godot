extends RefCounted
## My Journal (docs/my-journal.md): Luther's vague stuck-point notes. The notes are the JOURNAL_HINTS data that sits
## beside each planner's flags (owner rule 2026-10-27); a note is shown only after its moment was reached in play and
## recorded with discover(). Discovered ids live in the carried item_effects packet ("journal", discovery order), so
## they travel with every save and area handoff; older saves have none. Reading never changes quest state, and the
## developer "enhanced_guard" text is never shown. LoL2 has no journal of its own: the page is a presentation adapter.
const SOURCES := [
	["res://scripts/lol2/jungle_village_state.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/monastery_quest_state.gd", "CAN_JOURNAL_HINTS"],
	["res://scripts/lol2/monastery_quest_state.gd", "CHUT_JOURNAL_HINTS"],
	["res://scripts/lol2/thieves_den_state.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/weapon_shop_state.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/museum_long_arm_state.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/museum_torches.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l8_larkhon_state.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l8_tree.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l8_village_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l10_journal_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l9_journal_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l8_tribe_dawn_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l13_journal_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l14_journal_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/l16_journal_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/act1_journal_hints.gd", "JOURNAL_HINTS"],
	["res://scripts/lol2/act3_journal_hints.gd", "JOURNAL_HINTS"]]
const EMPTY := "Nothing worth writing down yet."
const NOTICE := "A new note in My Journal (J)."
static var _hints: Dictionary = {}

## Every note by its stable id (the hint's "when"), in source order.
static func hints() -> Dictionary:
	if _hints.is_empty():
		for source in SOURCES:
			var rows: Array = (load(source[0]) as Script).get_script_constant_map()[source[1]]
			for row in rows: _hints[str(row.when)] = str(row.hint)
	return _hints

static func validate(value: Variant) -> String:
	if value == null: return ""
	if not value is Array or value.size() > hints().size(): return "Invalid journal."
	var seen := {}
	for id in value:
		if not id is String or not hints().has(id) or seen.has(id): return "Invalid journal note."
		seen[id] = true
	return ""

## Discovered ids of a host's carried item_effects (all areas share player_item_controller.state()).
static func notes(host: Object) -> Array:
	var controller = host.get("item_effects") if host != null else null
	if controller == null or not is_instance_valid(controller) or not controller.has_method("state"): return []
	var journal = controller.state().get("journal", [])
	return journal if journal is Array else []

## Records a note the first time its moment is reached. Returns true only for a new note.
static func discover(host: Object, id: String) -> bool:
	if not hints().has(id):
		push_error("Unknown journal note: " + id)
		return false
	var controller = host.get("item_effects") if host != null else null
	if controller == null or not is_instance_valid(controller) or not controller.has_method("state"): return false
	var effects: Dictionary = controller.state()
	var journal: Array = effects.get("journal", [])
	if id in journal: return false
	journal.append(id)
	effects.journal = journal
	if host.has_method("save_feedback"): host.save_feedback(NOTICE)
	return true

static func page_text(ids: Array) -> String:
	if ids.is_empty(): return EMPTY
	var lines: Array[String] = []
	for id in ids: lines.append("— " + str(hints().get(id, "")))
	return "\n\n".join(lines)
