extends SceneTree
const State = preload("res://scripts/lol2/weapon_shop_state.gd")
func _initialize():
	var native: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/weapon_shop_admission.json"))
	for case in native.cases:
		var door := State.initial()
		door.flags = case.flags
		door.locals = case.locals
		door.globals = case.globals
		assert(State.admitted(door,case.power_orb_owned) == case.admitted)
	var s := State.initial()
	assert(State.validate(s).is_empty())
	assert(State.enter_exterior(s) and State.admitted(s))
	s.room = "WPN"
	State.begin(s,"intro")
	assert(State.flag(s,69) and not State.flag(s,65) and State.active(s))
	var partial: Dictionary = JSON.parse_string(JSON.stringify(s))
	assert(State.validate(partial).is_empty())
	State.advance(s,1000)
	assert(State.flag(s,65) and State.flag(s,66) and State.flag(s,67))
	assert(s.globals.GV_LUTHER_KNOWS_ABOUT_DANIEL == 1)
	assert(State.validate(s).is_empty())
	State.action(s,"orb")
	assert(not State.flag(s,254) and not s.globals.has("GV_KNOWLEDGE_OF_POWER_ORB"))
	var line: Array = State.Data.PLANS.orb[int(s.cursor)]
	State.advance(s,float(State.Data.DURATIONS[State.movie_key(line)])+0.01)
	assert(State.flag(s,254) and s.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1)
	assert(State.validate(s).is_empty())
	State.advance(s,1000)
	var effects := State.action(s,"shortsword")
	effects.append_array(State.advance(s,1000))
	assert(effects.filter(func(e): return e[0] == "give_item").size() == 1)
	assert(State.action(s,"shortsword").is_empty())
	assert(State.validate(s).is_empty())
	var broken: Dictionary = s.duplicate(true)
	broken.cursor = -1
	assert(not State.validate(broken).is_empty())
	broken = s.duplicate(true)
	broken.flags["62"] = 0
	assert(not State.validate(broken).is_empty())
	var known := State.initial()
	known.room="WPN"
	known.globals["GV_KNOWLEDGE_OF_POWER_ORB"]=1
	State.action(known,"orb")
	assert(known.sequence=="orb_preknown" and not State.flag(known,254))
	State.advance(known,1000)
	if not State.validate(known).is_empty(): print("Known orb state: ",known," error=",State.validate(known))
	assert(State.flag(known,254) and State.validate(known).is_empty())
	var trade := State.initial()
	trade.room="WPN"
	var offered := State.offer(trade,"83-Power orb")
	assert(offered==[["consume_held"]] and not State.flag(trade,63))
	var trade_save: Dictionary=JSON.parse_string(JSON.stringify(trade))
	assert(State.validate(trade_save).is_empty())
	var granted := State.advance(trade,1000)
	assert(granted==[["give_item","9-Firestorm",0]] and State.flag(trade,63))
	assert(trade.locals["Luther_has_firestorm"]==1 and State.validate(trade).is_empty())
	assert(State.offer(trade,"83-Power orb").is_empty())
	assert(State.advance(trade_save,1000)==granted)
	print("PASS: source weapon shop ordering, earned and preknown orb branches, one-shot grant and serialized partial state")
	quit()
