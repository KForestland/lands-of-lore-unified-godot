extends SceneTree
const State = preload("res://scripts/lol2/jungle_bridge_break_state.gd")
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; push_error(message)
func _initialize() -> void:
	var src := State.source()
	var s := State.initial()
	var p: Array = src.planks["210"].position
	var foot := Vector3(p[0], float(p[1])+float(src.planks["210"].box.height), p[2])
	check(State.advance(s,src,foot,true,0).is_empty() and not s.broken,"Human must not break bridge")
	check(State.advance(s,src,foot,true,1).is_empty(),"Changing form on same support is not a new support entry")
	State.advance(s,src,foot,false,1)
	check(State.advance(s,src,foot+Vector3.UP*10,true,1).is_empty(),"Above support must not break")
	var effects := State.advance(s,src,foot,true,1)
	check(s.broken,"Beast support entry did not break")
	check(effects.filter(func(e):return e.type=="group").map(func(e):return e.group)==[26868,26940],"Both original groups must be admitted before state changes")
	check(effects.filter(func(e):return e.type=="sound").map(func(e):return e.request)==[452],"Post-state-write sound must survive queued predicate admission")
	check(effects.filter(func(e):return e.type=="presence").size()==6,"All debris links required")
	var restored := State.canonical(JSON.parse_string(JSON.stringify(s)))
	check(State.validate(restored,src).is_empty(),"Serialized break state invalid")
	check(State.advance(restored,src,foot,true,1).is_empty(),"Reload retriggers support")
	State.advance(restored,src,foot,false,1)
	check(State.advance(restored,src,foot,true,1).is_empty(),"Broken bridge fires twice")
	for id in ["212","213","214"]:
		p = src.planks[id].position
		foot = Vector3(p[0],float(p[1])+float(src.planks[id].box.height),p[2])
		State.advance(restored,src,foot,false,0)
		effects = State.advance(restored,src,foot,true,0)
		check(effects.filter(func(e):return e.type=="sound").map(func(e):return e.request)==[int(src.creaks[id].sound)],"Human creak missing on "+id)
		State.advance(restored,src,foot,false,2)
		check(State.advance(restored,src,foot,true,2).is_empty(),"Lizard must not creak on "+id)
	var bad := restored.duplicate(true);bad.contact.owner=9999
	check(not State.validate(bad,src).is_empty(),"Unknown saved support accepted")
	if not failed: print("PASS jungle_bridge_break_state_test: source support transitions, forms, queued predicates, all debris, sounds and JSON continuation")
	quit(1 if failed else 0)
