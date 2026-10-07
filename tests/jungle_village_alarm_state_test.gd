extends SceneTree
## Village alarm source chain on the pure state.
## - Region3805 starts control216 timer1; without the alert its expiry runs nothing.
## - With the alert: g27172 (once, local32 latch) gives:
##   - the Kelsrick bundle in source order (locals 52/8/32, soul −2, sub13/sub7), plus g21418 (local52==1 overlay);
##   - movables 74/75/78/79 → 0 and 56/57 → 100; local7=2;
##   - timers 77/216 index0+2/217 started.
## - Bells (403) repeat while the alert holds. Arrows come from 77/216/217 and keep coming.
## - Bacatta57's raw op14 arms the same timer. Receipts are bounded and unique.
## - JSON round trip; malformed states rejected.
const State=preload("res://scripts/lol2/jungle_village_alarm_state.gd")
const Packet=preload("res://scripts/lol2/jungle_village_alarm_packet.gd")
var src: Dictionary
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func ctx(alert: int, locals: Dictionary) -> Dictionary: return {"shared":{"29":alert},"locals":locals}
## Kelsrick stand-in: applies the bundle's local writes so later predicates see them.
func apply_kelsrick(fx: Array, locals: Dictionary) -> void:
	for e in fx:
		if e.type!="kelsrick": continue
		for c in e.commands:
			var b: PackedByteArray=str(c).hex_decode()
			if b[0]==198: locals[str(int(b[4]))]=int(b[5])
func step(s: Dictionary, seconds: float, c: Dictionary, log: Array) -> void:
	for i in int(seconds*60):
		var fx:=State.advance(s,src,1.0/60,c)
		apply_kelsrick(fx,c.locals);log.append_array(fx)

func run() -> void:
	src=State.source()
	# No alert: the gate passage arms timer1, but its expiry (predicate192) runs nothing.
	var s:=State.initial(src)
	var fx:=State.enter_region(s,src,3805,ctx(0,{}))
	if not check(fx.any(func(e): return e.type=="external" and e.raw=="020100002500") and fx.any(func(e): return e.type=="external" and e.raw=="d20000000012"),"g7956 receipts %s"%[fx]): return
	if not check((int(s.timers["216"][1].flags)&1)==0 and (int(s.timers["216"][0].flags)&1)==1,"g7956 must start 216 timer1 only"): return
	var log: Array=[]
	var quiet:=ctx(0,{"32":0,"33":0,"52":0})
	step(s,7.0,quiet,log)
	if not check(not log.any(func(e): return e.type=="group" and int(e.group)==27172) and s.movables["78"]==-1,"Alarm ran without the alert"): return
	# Alert: the next expiry runs g27172 exactly once.
	var c:=ctx(1,{"32":0,"33":0,"52":0})
	log=[]
	step(s,6.0,c,log)
	var groups:=log.filter(func(e): return e.type=="group").map(func(e): return int(e.group))
	if not check(groups.count(27172)==1 and groups.has(21418) and not groups.has(21372),"Alarm groups %s"%[groups]): return
	var bundle: Array=log.filter(func(e): return e.type=="kelsrick" and int(e.group)==27172)[0].commands
	if not check(bundle==["c60000003401","ce00000000fe","c6000000081e","0d0240000d000000","0d02400007000000","c60000002001"],"Kelsrick bundle %s"%[bundle]): return
	if not check(log.filter(func(e): return e.type=="kelsrick" and int(e.group)==21418)[0].commands==["090240001100","0802400001000000","0d0240000d000000","0d02400007000000","c70000001d01"],"g21418 bundle"): return
	if not check(s.movables=={"56":100,"57":100,"74":0,"75":0,"78":0,"79":0} and int(s.locals["7"])==2,"Movables/local7 %s %s"%[s.movables,s.locals]): return
	for key in [["77",0],["216",0],["216",2],["217",0]]:
		if not check((int(s.timers[key[0]][key[1]].flags)&1)==0,"Timer %s not started"%[key]): return
	if not check(log.any(func(e): return e.type=="external" and e.raw=="051052000000") and log.any(func(e): return e.type=="external" and e.raw=="09204f001100"),"g27172 receipts"): return
	# Bells and arrows keep coming; g27172 never repeats (local32==1).
	log=[]
	step(s,20.0,c,log)
	var archers:={}
	for e in log:
		if e.type=="arrow": archers[str(int(e.control))]=int(archers.get(str(int(e.control)),0))+1
	if not check(archers.keys().size()==3 and archers.values().all(func(n): return n>=3),"Archers %s"%[archers]): return
	if not check(log.any(func(e): return e.type=="sound" and int(e.request)==403 and int(e.object)==510) and not log.any(func(e): return e.type=="group" and int(e.group)==27172),"Bells/latch differ"): return
	# Without the alert the bells stop, but the archers do not (no source stop).
	log=[];c.shared["29"]=0
	step(s,10.0,c,log)
	if not check(not log.any(func(e): return e.type=="sound") and log.any(func(e): return e.type=="arrow"),"Bells must follow the alert; arrows continue"): return
	# Bacatta57's g10162 op14 arms timer1 on a fresh state; other raw commands are refused.
	var b:=State.initial(src)
	if not check(State.arm(b,src,"0e10d80003000100") and (int(b.timers["216"][1].flags)&1)==0 and not State.arm(b,src,"0903e4010a00"),"Bacatta57 arming differs"): return
	# JSON round trip and validation.
	var saved=JSON.parse_string(JSON.stringify(s))
	if not check(State.validate(saved,src).is_empty() and State.canonical(saved)==s,"Round trip: %s"%State.validate(saved,src)): return
	if not check(Packet.validate({"version":1,"state":saved,"inside":false}).is_empty(),"Packet"): return
	for mutate in [func(x): x.movables["78"]=50, func(x): x.locals["7"]=300, func(x): x.timers["216"].pop_back(), func(x): x.receipts.append("zz"), func(x): x.ticks=1.0, func(x): x.extra=1]:
		var bad: Dictionary=State.canonical(saved);mutate.call(bad)
		if not check(not State.validate(bad,src).is_empty(),"Accepted a malformed alarm state"): return
	if not check(not Packet.validate({"version":1,"state":saved,"inside":3}).is_empty(),"Accepted a malformed packet"): return
	print("PASS jungle_village_alarm_state_test: g7956 arms 216/1; no alert -> inert; alert -> g27172 once (Kelsrick bundle + g21418, gates/doors/inner targets, local7, timers); bells follow the alert; three archers repeat; Bacatta57 arming; JSON/validation")
	quit(0)
