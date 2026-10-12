extends SceneTree
const Packet=preload("res://scripts/lol2/cave_lurking_roach_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
func _initialize() -> void:
	var src:=Packet.source();var s:=Packet.initial()
	assert(Packet.validate(s).is_empty())
	for id in ["36","37"]:
		assert(s.actors[id].present and s.actors[id].health==150)
		assert(Generic.damage(s,src,id,149)==149 and s.actors[id].health==1)
		assert(Generic.damage(s,src,id,20)==1 and s.actors[id].health==0)
	Generic.advance_clocks(s,src,10)
	assert(Packet.validate(s).is_empty())
	assert(Packet.validate(JSON.parse_string(JSON.stringify(s))).is_empty())
	var bad:=s.duplicate(true);bad.marker59=60;assert(not Packet.validate(bad).is_empty())
	bad=s.duplicate(true);bad.actors["36"].present=false;assert(not Packet.validate(bad).is_empty())
	print("PASS cave_lurking_roach_state_test: source-present150HP pair, death and marker validation")
	quit()
