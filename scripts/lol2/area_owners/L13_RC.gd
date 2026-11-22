extends RefCounted
## Ordered registrations from the unchanged d5da60a hosts (Plan1 stack 323aec5).
const OWNERS := [
	{"script": "l13_egg_door.gd", "phase": "early", "restore_order": 6},
	{"script": "l13_eggs.gd", "phase": "early", "restore_order": 7},
	{"script": "l13_elevator.gd", "attach": "attach_lift", "phase": "early", "static": ["owns_lift"], "collision": ["owns_lift"], "restore_order": 8, "restore_on": ["load"], "key": "l13_elevator", "validate": "validate_lift"},
	{"script": "l13_prison.gd", "phase": "early"},
	{"script": "l13_spires.gd", "phase": "early", "restore_order": 9},
	{"script": "l13_dawn_prison.gd", "phase": "early"},
	{"script": "l13_bridge.gd", "phase": "early", "restore_order": 10},
	{"script": "l13_belial.gd", "phase": "early"},
	{"script": "l13_altar.gd", "phase": "early", "restore_order": 11},
	{"script": "l13_return_pad.gd", "phase": "early"},
	{"script": "l13_exit_lock.gd", "phase": "early", "restore_order": 12},
	{"script": "l13_journal_hints.gd", "phase": "early", "args": ["citadel"]},
	{"script": "generic_object_actions.gd", "phase": "late", "needs": "progression"},
	{"script":"generic_object_world.gd","phase":"late","needs":"progression","static":[],"collision":[]},
]
