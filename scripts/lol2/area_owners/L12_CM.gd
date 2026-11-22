extends RefCounted
## Ordered registrations from the unchanged d5da60a hosts (Plan1 stack 323aec5).
const OWNERS := [
	{"script":"generic_object_world.gd","phase":"late","needs":"progression","static":[],"collision":[]},
	{"script": "l12_glacier.gd", "collision": ["owns_upper", "owns"], "restore_order": 5},
	{"script": "l12_river_rafts.gd", "restore_order": 4},
	{"script": "l12_niche_armor.gd", "restore_order": 3},
	{"script": "l12_crevasse.gd", "restore_order": 2},
	{"script": "l12_frozen_bow.gd", "restore_order": 1},
	{"script": "l12_citadel.gd"},
	{"script": "l12_tiger_platform.gd", "needs": "progression"},
	{"script": "l12_river_bank.gd"},
]
