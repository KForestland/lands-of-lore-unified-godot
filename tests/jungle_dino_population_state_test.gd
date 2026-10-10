extends SceneTree
const State=preload("res://scripts/lol2/jungle_dino_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Quests=preload("res://scripts/lol2/act_one_quest_state.gd")
func _initialize() -> void:
	var src:=State.source()
	assert(src.actors.size()==15 and src.reward_scale==4 and src.damage==24 and src.clips.bite.hit_frame==9 and src.clips.bite.frames==14)
	var s:=State.initial()
	assert(State.validate(s).is_empty() and s.actors["21"].health==150 and s.actors["21"].position==[-1740.0,30.0,-1718.0] and s.live["21"].heading==47149)
	var r:=State.rules()
	assert(is_equal_approx(r.impact,9.0/8.0) and is_equal_approx(r.clip,14.0/8.0))
	# Bite lands once at frame9 for the native24 request, capped by remaining health.
	s.live["24"].merge({"mode":Live.ATTACK,"elapsed":0.0,"hit":false},true)
	assert(Live.advance(s.live["24"],true,1.1,30,true,false,30,r)==0)
	assert(r.damage==10 and Live.advance(s.live["24"],true,0.05,30,true,false,30,r)==10)
	assert(Live.advance(s.live["24"],true,0.2,30,true,false,6,r)==0)
	s.live["24"].merge({"mode":Live.ATTACK,"elapsed":1.0,"hit":false},true)
	assert(Live.advance(s.live["24"],true,0.2,30,true,false,6,r)==6)
	var mid: Dictionary=JSON.parse_string(JSON.stringify(s,"",false,true))
	assert(State.validate(mid).is_empty() and State.canonical(mid)==State.canonical(s))
	# Damage, overkill, defeat clip and corpse.
	assert(State.damage(s,"24",100)==100 and s.actors["24"].health==50)
	assert(State.damage(s,"24",999)==50 and s.actors["24"].health==0 and s.live["24"].mode==Live.IDLE and State.damage(s,"24",5)==0)
	State.advance_death(s,9.0)
	assert(is_equal_approx(s.actors["24"].death,State.DEATH_SECONDS) and State.validate(s).is_empty())
	# Quest transport validates the packet.
	var quests:=Quests.initial();quests.jungle_dino_population=s
	assert(Quests.validate(quests).is_empty())
	for change in [["actors","21","health",151],["actors","21","death",0.5],["live","21","mode",4],["live","22","heading",70000]]:
		var bad: Dictionary=State.canonical(s);bad[change[0]][change[1]][change[2]]=change[3]
		assert(not State.validate(bad).is_empty())
		quests.jungle_dino_population=bad
		assert(not Quests.validate(quests).is_empty())
	for value in [-0.1,0.451,"0.1",INF,NAN]:
		var bad:=State.canonical(s);bad.strike_remaining=value
		assert(not State.validate(bad).is_empty())
	s.strike_remaining=0.45
	assert(State.validate(s).is_empty() and State.canonical(JSON.parse_string(JSON.stringify(s)))==s)
	var missing: Dictionary=State.canonical(s);missing.actors.erase("35")
	assert(not State.validate(missing).is_empty())
	assert(preload("res://scripts/lol2/player_spark_aura_state.gd").valid_target("jungledino35") and not preload("res://scripts/lol2/player_spark_aura_state.gd").valid_target("jungledino36"))
	print("PASS: 15 source DINOs/150HP/scale4, bite at frame9 once (native24 request, playable10), cap, defeat/corpse clock, JSON, quest validation and malformed rejection")
	quit()
