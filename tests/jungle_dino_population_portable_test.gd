extends SceneTree
## Asset-free subset of jungle_dino_population_state_test (no quest/aura owners).
const State=preload("res://scripts/lol2/jungle_dino_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
func _initialize() -> void:
	var src:=State.source()
	assert(src.actors.size()==15 and src.reward_scale==4 and src.damage==24 and src.clips.bite.hit_frame==9)
	var s:=State.initial()
	assert(State.validate(s).is_empty() and s.actors["21"].health==150)
	var r:=State.rules()
	s.live["24"].merge({"mode":Live.ATTACK,"elapsed":0.0,"hit":false},true)
	assert(Live.advance(s.live["24"],true,1.1,30,true,false,30,r)==0 and Live.advance(s.live["24"],true,0.05,30,true,false,30,r)==10)
	var mid: Dictionary=JSON.parse_string(JSON.stringify(s,"",false,true))
	assert(State.validate(mid).is_empty() and State.canonical(mid)==State.canonical(s))
	assert(State.damage(s,"24",999)==150 and s.live["24"].mode==Live.IDLE)
	State.advance_death(s,9.0)
	assert(State.validate(s).is_empty())
	var bad: Dictionary=State.canonical(s);bad.live["21"].mode=4
	assert(not State.validate(bad).is_empty())
	print("PASS: portable DINO source/bite24/JSON/defeat/malformed checks")
	quit()
