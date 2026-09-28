extends SceneTree
const S=preload("res://scripts/lol2/hive_ambush_state.gd")
func _initialize() -> void:
	var s:=S.initial()
	assert(S.validate(s).is_empty())
	S.advance(s,0.5)
	assert(s.actors["33"].elapsed==0 and s.actors["35"].elapsed==0.5)
	assert(S.arm(s,33) and S.arm(s,35,true))
	S.advance(s,1.0)
	assert(not s.actors["33"].active and s.actors["35"].phase==1)
	var restored:=S.canonical(JSON.parse_string(JSON.stringify(s)))
	assert(restored==s and S.validate(restored).is_empty())
	S.advance(s,0.7)
	assert(s.actors["33"].active and s.actors["35"].phase==1)
	S.advance(s,2.0)
	assert(s.actors["35"].phase==2)
	S.advance(s,1.0)
	assert(s.actors["35"].active and S.validate(s).is_empty())
	s.actors["33"].health=0
	assert(not S.arm(s,33) and not S.arm(s,35,true))
	S.advance(s,50)
	assert(s.actors["33"].health==0 and S.validate(s).is_empty())
	for pair in [["health",401],["phase",2],["active",false],["elapsed",0.5],["windup",1.2],["seed",-1],["position",[INF,0,0]]]:
		var bad:=s.duplicate(true)
		bad.actors["33"][pair[0]]=pair[1]
		assert(not S.validate(bad).is_empty())
	var bad:=s.duplicate(true)
	bad.local7=0
	assert(not S.validate(bad).is_empty())
	print("PASS ambush stages, partial JSON, independent timers, saved defeat and malformed rejection")
	quit()
