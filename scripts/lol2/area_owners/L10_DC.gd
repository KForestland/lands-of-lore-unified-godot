extends RefCounted
## Ordered registrations from the unchanged d5da60a hosts (Plan1 stack 323aec5).
const OWNERS := [
	{"script": "l10_main_gate.gd", "phase": "early"},
	{"script": "l10_tombs.gd", "phase": "early"},
	{"script": "l10_braziers.gd", "phase": "early"},
	{"script": "l10_fences.gd", "phase": "early", "restore_order": 0},
	{"script": "l10_barrel.gd", "phase": "early"},
	{"script": "l10_oil.gd", "phase": "early"},
	{"script": "l10_priest.gd", "phase": "early"},
	{"script": "l10_emperor_entry.gd", "attach": "attach_entry", "phase": "early", "static": ["entry_owns"], "collision": ["entry_owns"], "key": "l10_ankh", "validate": "", "restore_on": []},
	{"script": "l10_emperor.gd", "phase": "early"},
	{"script": "l10_silverleaf.gd", "phase": "early"},
	{"script": "generic_object_world.gd", "phase": "late", "needs": "progression"},
	{"script": "l10_journal_hints.gd", "phase": "early"},
	{"script": "l8_tribe_dawn_hints.gd", "phase": "early", "args": ["remains"]},
]

const Tombs = preload("res://scripts/lol2/l10_tomb_state.gd")
const STATIC_ASSEMBLIES := [61,70,165,166,167,168,169,170,171,172,173]
const COLLISION_ASSEMBLIES := [70,74,75,174,67]
static func claims_static(face: Dictionary) -> bool:
 return face.get("placement_kind") == "static_assembly" and (int(face.get("source_index", -1)) in STATIC_ASSEMBLIES or int(face.get("source_index", -1)) in Tombs.doors())
static func claims_collision(face: Dictionary) -> bool:
 if face.get("placement_kind") != "static_assembly": return false
 var index := int(face.get("source_index", -1))
 return index in COLLISION_ASSEMBLIES or index in Tombs.doors() or Tombs.ROWS.has(str(index))
