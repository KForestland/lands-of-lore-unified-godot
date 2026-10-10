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
	var r: Dictionary={}
	for region in src.regions: r[int(region.region)]=region
	# Region631 alone spawns39 dormant (its scripted wake is pending).
	var s2:=State.initial(src)
	State.contact(s2,src,centre(r[631]),float(r[631].floor_min))
	assert(s2.actors["39"].present and not s2.actors["39"].woken)
	# Regions769/772/775 disarm control109 and retain wake commands, never spawn39.
	State.contact(s,src,centre(r[769]),float(r[769].floor_min))
	assert(not s.actors["39"].present and s.actors["39"].woken and s.regions==[769] and s.controls["109"]==1 and s.wake_groups.local34)
	State.contact(s,src,centre(r[772]),float(r[772].floor_min))
	assert(s.regions==[769,772])
	State.contact(s,src,centre(r[775]),float(r[775].floor_min))
	State.advance_clocks(s,src,2.0)
	assert(not s.actors["39"].present and not State.ready_to_fight(s,src,"39") and s.actors["39"].rise==0.0)
	assert(State.use_control(s,src,"109").is_empty())
	State.contact(s,src,centre(r[631]),float(r[631].floor_min))
	assert(s.actors["39"].present and s.actors["39"].woken and s.actors["39"].rise==0.0)
	State.contact(s2,src,centre(r[775]),float(r[775].floor_min))
	assert(s2.actors["39"].present and s2.actors["39"].woken and s2.controls["109"]==1)
	# Source shared45=GV_LUTHER_FORM: nonhuman entry disarms, but cannot wake.
	for form in [1,2]:
		var transformed:=State.initial(src)
		State.contact(transformed,src,centre(r[775]),float(r[775].floor_min),form)
		assert(not transformed.wake_groups.local34 and not transformed.actors["39"].woken and transformed.controls["109"]==1)
		var paused: Dictionary=State.canonical(JSON.parse_string(JSON.stringify(transformed)),src)
		State.contact(paused,src,centre(r[775]),float(r[775].floor_min),0)
		assert(not paused.wake_groups.local34) # Morphing/loading while inside is not a new entry.
		State.contact(paused,src,Vector3(30000,0,30000),0.0,0)
		State.contact(paused,src,centre(r[775]),float(r[775].floor_min),0)
		assert(paused.wake_groups.local34 and paused.actors["39"].woken and not paused.actors["39"].present)
		assert(State.validate(paused,src).is_empty())
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
	assert(s.actors["52"].woken and s.controls["114"]==1)
	var mid: Dictionary=JSON.parse_string(JSON.stringify(s,"",false,true))
	assert(State.validate(mid,src).is_empty() and State.canonical(mid,src)==State.canonical(s,src))
	var legacy:=mid.duplicate(true);legacy.erase("controls");legacy.erase("wake_groups");legacy.erase("contacts")
	assert(State.validate(legacy,src).is_empty())
	assert(State.canonical(legacy,src).controls==s.controls)
	assert(State.canonical(legacy,src).wake_groups.local34)
	assert(State.canonical(legacy,src).actors==State.canonical(s,src).actors)
	var wrong_keys:=mid.duplicate(true);wrong_keys.controls.erase("109");wrong_keys.controls["999"]=1
	assert(not State.validate(wrong_keys,src).is_empty())
	assert(State.damage(s,src,"38",999)==150 and s.actors["38"].health==0 and State.validate(s,src).is_empty())
	assert(State.damage(s,src,"56",5)==0)
	var bad: Dictionary=State.canonical(s,src);bad.actors["54"].health=10
	assert(not State.validate(bad,src).is_empty())
	print("PASS: cave region control109/114 disarm without false spawn; region631 dormant spawn; wake52; JSON and legacy control restoration; rise, hit, defeat and malformed rejection")
	quit()
