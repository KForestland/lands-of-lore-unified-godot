extends SceneTree
const State=preload("res://scripts/lol2/museum_skeleton_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
func _initialize() -> void:
	var src:=State.source()
	var s:=State.initial()
	assert(State.validate(s).is_empty() and s.actors.size()==13 and src.counted.size()==10)
	# Source health/definitions; scripted actors dormant, unscripted ones (Rat22, skel23) use perception.
	assert(s.actors["24"].health==100 and s.actors["32"].health==150 and s.actors["22"].health==40)
	for id in ["20","21","24","25","26","27","28","29","30","31","32"]: assert(not s.actors[id].woken,id)
	assert(s.actors["22"].woken and s.actors["23"].woken)
	# Placement flag0x1000: 21 and30 are absent until an op9 property3 spawn.
	assert(not s.actors["21"].present and not s.actors["30"].present and s.actors["24"].present)
	assert(State.damage(s,src,"30",5)==0 and not State.ready_to_fight(s,src,"30"))
	# Native requests: 50% hit =7, 100% =15; selector12/13 two-hit clip.
	var r:=State.attack_rules(src,"24",2)
	assert(r.impacts.size()==2 and r.impacts[0][1]==3 and r.impacts[1][1]==3 and is_equal_approx(r.impacts[1][0],11.0/8.0))
	assert(State.attack_rules(src,"24",1).impacts[0][1]==6 and State.attack_rules(src,"22",0).impacts[0][1]==6)
	# Region35 wakes exactly24/25/26, once; others untouched.
	var r35: Dictionary=src.regions.filter(func(x):return int(x.region)==35)[0]
	var c:=Vector2.ZERO
	for v in r35.polygon: c+=Vector2(v[0],v[1])
	c/=r35.polygon.size()
	var woke:=State.contact(s,src,Vector3(c.x,0,c.y),float(r35.floor_min))
	assert(woke.size()==3 and "24" in woke and s.regions==[35] and not s.actors["27"].woken)
	assert(State.contact(s,src,Vector3(c.x,0,c.y),float(r35.floor_min)).is_empty())
	assert(not State.ready_to_fight(s,src,"24") and State.validate(s).is_empty())
	State.advance_clocks(s,src,2.0)
	assert(State.ready_to_fight(s,src,"24"))
	# Neighbour wake: hitting dormant27 wakes only itself; hitting24..26 wakes the trio.
	assert(State.damage(s,src,"27",5)==5 and s.actors["27"].woken and not s.actors["28"].woken)
	# Two-hit clip: variant2 lands7 at frame6 and7 at frame11, once each.
	s.live["24"].merge({"mode":Live.ATTACK,"elapsed":0.0,"hit":false,"hits":0,"attack":2},true)
	var total:=0
	for i in 16: total+=State.advance_live(s,src,"24",1.0/8.0,30,true,false,30)
	assert(total==6 and s.live["24"].attack==0,"two-hit clip total %d" % total)
	assert(State.validate(s).is_empty())
	var mid: Dictionary=JSON.parse_string(JSON.stringify(s,"",false,true))
	assert(State.validate(mid).is_empty() and State.canonical(mid)==State.canonical(s))
	# Ten deaths increment local23 without inventing a prop state; Rat and actors20/21 do not count.
	assert(State.damage(s,src,"22",99)==40 and s.counter==0)
	# Control96 (not yet live) spawns30; stand in for it here.
	assert(State.spawn(s,"30") and not State.spawn(s,"30"))
	for id in ["23","24","25","26","27","28","29","30","31"]: State.damage(s,src,id,999)
	assert(s.counter==9 and s.prop93==0 and State.validate(s).is_empty())
	State.damage(s,src,"32",999)
	assert(s.counter==10 and s.prop93==0 and State.validate(s).is_empty())
	assert(State.damage(s,src,"32",5)==0 and s.counter==10)
	var legacy:=s.duplicate(true);legacy.prop93=3
	assert(State.validate(legacy).is_empty() and State.canonical(legacy).prop93==0)
	for change in [["counter",11],["prop93",2]]:
		var bad: Dictionary=State.canonical(s);bad[change[0]]=change[1]
		assert(not State.validate(bad).is_empty())
	var bad2: Dictionary=State.initial();bad2.live["28"].mode=Live.PURSUE
	assert(not State.validate(bad2).is_empty())
	print("PASS: 13 source Museum creatures, scripted dormancy, region35 wake, neighbour/damage wake, rise, two-hit clip3+3 (native7+7 requests), JSON, ten-death counter with legacy receipt migration and malformed rejection")
	quit()
