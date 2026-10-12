extends SceneTree
const S=preload("res://scripts/lol2/jungle_drunk_state.gd")
func _initialize() -> void:
	var src:=S.source();var s:=S.initial();var ctx:={"locals":{"7":0},"shared":{}}
	assert(S.validate(s,src).is_empty())
	S.event(s,src,"prop",484,5,0,ctx)
	assert(s.segment==1 and s.blocked and not s.hold)
	var e:=S.event(s,src,"control",110,4,0,ctx)
	assert(s.segment==0 and s.hold and s.focus and e.any(func(x):return x.type=="local7" and x.value==1))
	assert(e.any(func(x):return x.type=="reposition"))
	ctx.locals["7"]=1
	S.advance(s,src,5.0,ctx)
	var disk: Dictionary=JSON.parse_string(JSON.stringify(s));assert(S.validate(disk,src).is_empty())
	S.advance(disk,src,30.0,ctx);assert(disk.segment==1 and not disk.hold and not disk.focus)
	e=S.event(disk,src,"region",3651,2,0,ctx);assert(e.any(func(x):return x.type=="local7" and x.value==2))
	ctx.locals["7"]=2
	S.event(disk,src,"control",110,5,0,ctx);assert(not disk.present and not disk.blocked and S.validate(disk,src).is_empty())
	s=S.initial();ctx.locals["7"]=0;S.event(s,src,"prop",485,5,0,ctx)
	e=S.event(s,src,"control",110,9,0,ctx)
	assert(s.segment==2 and s.owner_state==1 and not s.hold and e.any(func(x):return x.type=="soul" and x.delta==-1))
	S.advance(s,src,5.0,ctx);assert(s.segment==-1)
	var malformed:=s.duplicate(true);malformed.segment=0.5;assert(not S.validate(malformed,src).is_empty())
	malformed=s.duplicate(true);malformed.elapsed=NAN;assert(not S.validate(malformed,src).is_empty())
	s=S.initial();ctx.locals["7"]=2;S.event(s,src,"prop",484,5,0,ctx);assert(s.segment==-1)
	var packet:={"version":1,"state":S.initial(),"inside":[]}
	var validator=preload("res://scripts/lol2/jungle_drunk_packet.gd")
	assert(validator.validate(packet).is_empty())
	packet.inside=[3651,3651];assert(not validator.validate(packet).is_empty())
	packet.inside=[1.5];assert(not validator.validate(packet).is_empty())
	packet.inside=[3651];assert(validator.validate(JSON.parse_string(JSON.stringify(packet))).is_empty())
	print("PASS drunk state: source sight, offer, hold/reposition, JSON mid-line, completion idle, departure release, hit/soul, malformed rejection and alert suppression.")
	quit()
