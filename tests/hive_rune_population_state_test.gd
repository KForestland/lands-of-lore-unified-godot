extends SceneTree
const State=preload("res://scripts/lol2/hive_rune_population_state.gd")
func _initialize() -> void:
	var s:=State.initial()
	assert(State.validate(s).is_empty() and State.summon(s,true).is_empty())
	State.observe(s,{"32":true,"34":true})
	assert(State.advance(s,4.5,{"32":true,"34":true}).is_empty())
	var resumed:=State.canonical(JSON.parse_string(JSON.stringify(s)))
	assert(State.advance(s,0.5,{"32":true,"34":true})==[32])
	assert(State.advance(resumed,0.5,{"32":true,"34":true})==[32] and resumed==s)
	assert(State.advance(s,1,{"32":true,"34":true})==[34])
	s.slots["32"].inventory=["held-item"]
	assert(State.summon(s,false).is_empty())
	var copies:=State.summon(s,true)
	assert(copies==[{"slot":32,"template":22,"generation":1},{"slot":34,"template":21,"generation":1}])
	assert(s.slots["32"].inventory==["held-item"] and State.summon(s,true).is_empty())
	assert(State.validate(s).is_empty())
	assert(State.validate(JSON.parse_string(JSON.stringify(s))).is_empty())
	s.actors["32"].health=0;s.actors["32"].death_animation={"corpse":true,"frame":0,"timer":0,"fraction":0.0}
	State.observe(s,{})
	assert(State.advance(s,5,{}).is_empty()) # Nonempty inventory is not silently destroyed.
	s.slots["32"].inventory=[]
	assert(State.advance(s,1,{})==[32])
	assert(State.summon(s,true)==[{"slot":32,"template":22,"generation":2}])
	var bad:=s.duplicate(true);bad.slots["32"].phase=2
	assert(not State.validate(bad).is_empty())
	bad=s.duplicate(true);bad.slots.erase("23");assert(not State.validate(bad).is_empty())
	print("PASS: finite slot admission, delayed retirement, cleanup serialization, template order, inventory retention, saved fractional clock and repeat generations")
	quit()
