extends SceneTree
## The Godot planner reproduces all 32 native MLIB 0x98F/0xF09 cases (docs/mlib-dawn-attack-checks.json), and a first
## attack makes Dawn absent from the library and arms the Hive Dawn20 precondition.
const Attack=preload("res://scripts/lol2/monastery_library_attack.gd")
const Quests=preload("res://scripts/lol2/monastery_quest_state.gd")
func _initialize() -> void:
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/mlib-dawn-attack-checks.json"))
	var n:=0
	for c in report.cases:
		var out:=Attack.attacked(int(c.message),int(c.present)!=0,int(c.guard)!=0,c.flags,c.globals)
		var native_effects: Array=c.effects.map(func(e): return e.map(func(v): return int(v) if (v is float) else v))
		if out.handled!=int(c.handled) or out.effects!=native_effects or int(out.present)!=int(c.dawn_present_after) or int(out.guard)!=int(c.guard_after):
			push_error("Native case differs: %s → %s"%[JSON.stringify(c),JSON.stringify(out)]);quit(1);return
		n+=1
	var state:=Quests.initial();state.globals.GV_LUTHERS_SOUL=3
	var first:=Attack.attacked(7,true,false,state.flags,state.globals)
	Attack.apply(state,first.effects)
	if not (int(state.globals.GV_DAWN_ATTACKED_IN_MONASTERY)==1 and int(state.flags["191"])==1 and int(state.globals.GV_LUTHERS_SOUL)==2 and Quests.validate(state).is_empty()):
		push_error("Applied first attack differs");quit(1);return
	print("PASS monastery library attack: %d native MLIB cases reproduced; first attack sets GV_DAWN_ATTACKED_IN_MONASTERY, flag191 (Dawn leaves), soul−1, valid monastery state. Input behind messages 6/7 unbound."%n)
	quit()
