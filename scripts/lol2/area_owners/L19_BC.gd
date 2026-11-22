extends RefCounted
## Ordered registrations from the unchanged d5da60a hosts (Plan1 stack 323aec5).
const OWNERS := [
	{"script": "l19_beast_wall.gd", "needs": "progression"},
	{"script": "l19_belial_horn.gd", "needs": "progression"},
	{"script": "l19_sewer_forms.gd", "needs": "progression"},
	{"script": "l19_lab_ledge.gd", "needs": "progression"},
	{"script": "l19_drain_path.gd", "needs": "progression"},
	{"script": "l19_ghostly_heads.gd", "needs": "progression"},
	{"script": "l19_dawn_curse.gd", "needs": "progression"},
	{"script": "l19_dawn_elevator.gd", "needs": "progression", "restore_order": 13},
	{"script": "placed_vqa_billboard.gd", "attach": "attach_dawn", "needs": "progression"},
	{"script": "generic_object_actions.gd", "phase":"late", "needs":"progression"},
	{"script":"generic_object_world.gd","phase":"late","needs":"progression","static":[],"collision":[]},
]
