extends SceneTree
const State=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const SOURCE="res://scripts/lol2/cave_guard_population_source.json"
func centre(region: Dictionary) -> Vector3:
	var c:=Vector2.ZERO
	for v in region.polygon: c+=Vector2(v[0],v[1])
	c/=region.polygon.size()
	return Vector3(c.x,0,c.y)
func _initialize() -> void:
	var src:=State.source(SOURCE)
	var s:=State.initial(src)
	assert(State.validate(s,src).is_empty() and s.actors.size()==8)
	# Placement flag0x1000: only guard52 starts in the world; it waits for region1104.
	for id in ["1","2","38","39","53","54","56"]: assert(not s.actors[id].present,id)
	assert(s.actors["52"].present and not s.actors["52"].woken and not State.ready_to_fight(s,src,"52"))
	# Region769 (wake39) before region631 (spawn39) does nothing: absent actors cannot wake.
	var r: Dictionary={}
	for region in src.regions: r[int(region.region)]=region
	State.contact(s,src,centre(r[769]),float(r[769].floor_min))
	assert(not s.actors["39"].present and not s.actors["39"].woken and s.regions==[769])
	# Region631 spawns39; it was scripted dormant, so it rises only after a wake region.
	State.contact(s,src,centre(r[631]),float(r[631].floor_min))
	assert(s.actors["39"].present and not s.actors["39"].woken)
	State.contact(s,src,centre(r[772]),float(r[772].floor_min))
	assert(s.actors["39"].woken)
	State.advance_clocks(s,src,2.0)
	assert(State.ready_to_fight(s,src,"39"))
	# Region1941 spawns38 which fights directly (no later wake command).
	State.contact(s,src,centre(r[1941]),float(r[1941].floor_min))
	assert(s.actors["38"].present and s.actors["38"].woken and not State.ready_to_fight(s,src,"38"))
	State.advance_clocks(s,src,2.0)
	assert(State.ready_to_fight(s,src,"38"))
	# Guard hits: 100% request15 -> playable6, frame7.
	var rules:=State.attack_rules(src,"38",0)
	assert(rules.impacts.size()==1 and rules.impacts[0][1]==6 and is_equal_approx(rules.impacts[0][0],7.0/8.0))
	# Region1104 wakes52 in place.
	State.contact(s,src,centre(r[1104]),float(r[1104].floor_min))
	assert(s.actors["52"].woken)
	var mid: Dictionary=JSON.parse_string(JSON.stringify(s,"",false,true))
	assert(State.validate(mid,src).is_empty() and State.canonical(mid,src)==State.canonical(s,src))
	assert(State.damage(s,src,"38",999)==150 and s.actors["38"].health==0 and State.validate(s,src).is_empty())
	assert(State.damage(s,src,"56",5)==0)
	var bad: Dictionary=State.canonical(s,src);bad.actors["54"].health=10
	assert(not State.validate(bad,src).is_empty())
	print("PASS: 8 source cave guards; absent until region spawn (631/1941), wake only when present (769-775/1104), rise, playable6 hit, JSON, defeat and malformed rejection")
	quit()
