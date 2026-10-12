extends SceneTree
## Bacatta57 source chain on the pure state.
## - The native new-game relationship (1) leaves region3501 inert. Relationship 0 (after the CAN farewell) runs g10162:
##   alarm timer reported external, threshold sealed, doors target100, actor57 linked.
## - The door clock reaches the shut pose. A strike makes the linked body hostile once.
## - Region3157 removes 57 only when met. Region3501 entries without event20 effects stay inert.
## - Checkpoints round-trip through JSON. Malformed and unreachable packets are rejected.
const State=preload("res://scripts/lol2/jungle_bacatta57_state.gd")
const Packet=preload("res://scripts/lol2/jungle_bacatta57_packet.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
var src: Dictionary
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func ctx(rel: int, met: int) -> Dictionary: return {"shared":{"13":rel,"18":met}}
func types(fx: Array) -> Array: return fx.map(func(e): return str(e.type))

func run() -> void:
	src=State.source()
	# Native globals pinned from GLOBAL.MIX: only soul 5 and both relationships 1 are nonzero.
	var nonzero:={}
	for k in src.native_initial:
		if int(src.native_initial[k])!=0: nonzero[k]=int(src.native_initial[k])
	if not check(nonzero=={"GV_LUTHERS_SOUL":5,"GV_DAWN_RELATIONSHIP":1,"GV_BACATTA_RELATIONSHIP":1},"Native globals %s"%nonzero): return
	# Relationship at its native start (1): entering the village threshold changes nothing here.
	var s:=State.initial(src)
	var fx:=State.enter_region(s,src,3501,ctx(1,1))
	if not check(s==State.initial(src),"Relationship 1 must leave Bacatta57 untouched"): return
	if not check(types(fx).has("external") and types(fx).has("return_point") and not types(fx).has("sealed"),"g7026 alone: %s"%[types(fx)]): return
	# Relationship 0: g10162.
	fx=State.enter_region(s,src,3501,ctx(0,1))
	var t:=types(fx)
	if not check(s.sealed and int(s.doors.target)==100 and s.actor.present and int(s.actor.b5)==0,"g10162 effects %s"%[s]): return
	if not check(t.has("sealed") and t.count("doors")==2 and t.has("actor_presence") and fx.any(func(e): return e.type=="external" and e.raw=="0e10d80003000100"),"g10162 effect log %s"%[fx]): return
	if not check(t.find("group")<t.find("sealed") and fx.filter(func(e): return e.type=="group").map(func(e): return int(e.group))==[7026,10162],"Group order %s"%[fx]): return
	if not check(not State.hostile(s),"Linked Bacatta57 must be non-hostile"): return
	# Door clock: shut after DOOR_SECONDS, never beyond.
	for i in 200: State.advance(s,1.0/60)
	if not check(State.door_percent(s)==100 and float(s.doors.elapsed)==State.DOOR_SECONDS,"Doors shut %s"%[s.doors]): return
	# Strike: hostile once.
	if not check(types(State.struck(s))==["hostile"] and State.hostile(s) and int(s.actor.b5)==12,"Strike → hostile"): return
	if not check(State.struck(s).is_empty(),"Second strike adds nothing"): return
	# Region3157: not met → nothing; met → actor removed (65's half external).
	var before:=s.duplicate(true)
	State.enter_region(s,src,3157,ctx(0,0))
	if not check(s==before,"Region3157 needs GV_MET_BACATTA"): return
	fx=State.enter_region(s,src,3157,ctx(0,1))
	if not check(not s.actor.present and fx.any(func(e): return e.type=="external" and e.raw=="090241000200"),"Region3157 removal %s"%[fx]): return
	# Unknown regions are inert.
	if not check(State.enter_region(s,src,3503,ctx(0,1)).is_empty(),"Region3503 has no records"): return
	# The village alarm shuts the doors without sealing the threshold or linking Bacatta57.
	var alarm:=State.initial(src)
	if not check(State.shut(alarm).size()==2 and int(alarm.doors.target)==100 and not alarm.sealed and State.validate(alarm,src).is_empty() and State.shut(alarm).is_empty(),"Alarm shut differs"): return
	# JSON round trip and validation.
	var saved=JSON.parse_string(JSON.stringify(s))
	if not check(State.validate(saved,src).is_empty() and State.canonical(saved)==s,"Round trip"): return
	for bad in [
		{"version":2,"sealed":false,"doors":{"target":0,"elapsed":0.0},"actor":{"present":false,"b5":0}},
		{"version":1,"sealed":false,"doors":{"target":0,"elapsed":0.5},"actor":{"present":false,"b5":0}},
		{"version":1,"sealed":false,"doors":{"target":0,"elapsed":0.0},"actor":{"present":true,"b5":0}},
		{"version":1,"sealed":true,"doors":{"target":0,"elapsed":0.0},"actor":{"present":true,"b5":0}},
		{"version":1,"sealed":true,"doors":{"target":50,"elapsed":0.0},"actor":{"present":true,"b5":0}},
		{"version":1,"sealed":true,"doors":{"target":100,"elapsed":9.0},"actor":{"present":true,"b5":0}},
		{"version":1,"sealed":true,"doors":{"target":100,"elapsed":0.5},"actor":{"present":true,"b5":4}},
		{"version":1,"sealed":true,"doors":{"target":100,"elapsed":0.5},"actor":{"present":true,"b5":0},"x":1}]:
		if not check(not State.validate(bad,src).is_empty(),"Accepted bad branch %s"%[bad]): return
	# Packet: body must agree with the branch.
	var pop:=Generic.source(Packet.POPULATION)
	var body:=Generic.initial(pop)
	var packet:={"version":1,"branch":State.initial(src),"body":body,"inside":[]}
	if not check(Packet.validate(packet).is_empty(),"Initial packet: %s"%Packet.validate(packet)): return
	var linked:=packet.duplicate(true);linked.branch=s.duplicate(true);linked.branch.actor.present=true
	if not check(not Packet.validate(linked).is_empty(),"Branch/body disagreement accepted"): return
	Generic.spawn(linked.body,"57")
	if not check(Packet.validate(linked).is_empty(),"Linked packet: %s"%Packet.validate(linked)): return
	for bad_inside in [[3501,3501],[9999],[1.5]]:
		var p2:=packet.duplicate(true);p2.inside=bad_inside
		if not check(not Packet.validate(p2).is_empty(),"Accepted inside %s"%[bad_inside]): return
	print("PASS jungle_bacatta57_state_test: native relationship1 inert; relationship0 seals 3501, shuts doors 56/57, links non-hostile 57; strike hostile; 3157 removal when met; JSON/packet validation")
	quit(0)
