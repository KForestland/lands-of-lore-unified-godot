extends RefCounted
## Ordered registrations from the unchanged d5da60a hosts (Plan1 stack 323aec5).
const OWNERS := [
	{"script":"generic_object_world.gd","phase":"late","needs":"progression","static":[],"collision":[]},
	{"script": "l9_magic_bridge.gd", "key": "l9_magic_bridge"},
	{"script": "l9_tower.gd", "key": "l9_tower"},
	{"script": "l9_dead_bracers.gd", "key": "l9_dead_bracers"},
	{"script": "l9_mirrors.gd", "key": "l9_mirrors"},
	{"script": "l9_noble_rails.gd"},
	{"script": "l9_pyre.gd"},
	{"script": "l9_statue.gd"},
	{"script": "l9_statue_walk.gd", "key": "l9_statue_walk", "restore_order": 1},
	{"script": "l9_flood.gd"},
	{"script": "l9_journal_hints.gd"},
	{"script": "l9_escape.gd", "restore_order": 0, "restore_args": [true]},
]

const STATIC_ASSEMBLIES := [312,478,479,480,122,82]
static func claims_static(face: Dictionary) -> bool:
 return face.get("placement_kind") == "static_assembly" and int(face.get("source_index", -1)) in STATIC_ASSEMBLIES
