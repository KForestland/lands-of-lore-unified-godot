extends SceneTree
## Village Confidante on the pure state (supplied contexts; not a route).
## - Contract: the kill groups 25628/25802 carry the verified bytes; the gate-leaf groups stay recorded as not hosted.
## - First meeting: barrel prop1465 sighted (Daniel known) links control123 idling; region3408 holds Luther; the next idle
##   loop end plays the conversation and starts timer prop68 (23 s: Met_Confidant); the end releases and unlinks it.
##   A mid-conversation JSON save continues identically. Region3397 then sets local20=2.
## - Second meeting: prop492 sighted (Anyar attacked, Met) links control112; region3408 (p175) and its conversation end
##   add one Soul.
## - Kills: a hit on an idling control runs its kill group once (local39=1, Soul-1, death segment, state5; 123 also
##   prop492 state5 and sound269); the state5 end unlinks it with sound227. A second hit does nothing. After killing 123,
##   prop492 can no longer link 112; after killing 112, region3408 (p175 local39==0) starts nothing.
## - A region hold for a silent control first runs its sight event, and releases Luther if that cannot start it.
## - Mode1 admission (Grok replay b63a4ba rerun by Codex, AI_COMMS/codex_act1_review_20261025/village_dispatch): a hit
##   amount (context +0x1E) of 0 or less changes nothing and keeps the one-shot; 1 or more admits the kill once.
## - Malformed states are rejected.
const State=preload("res://scripts/lol2/jungle_confidante_state.gd")
var failed:=false
var src: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func ctx(daniel: int=1, smoked: int=0, anyar: int=0, soul: int=5) -> Dictionary:
	return {"locals":{"6":smoked,"33":anyar},"shared":{"0":soul,"25":0,"29":0,"47":daniel}}
func of(e: Array, t: String) -> Array: return e.filter(func(x): return x.type==t)
func groups(e: Array) -> Array: return of(e,"group").map(func(x): return int(x.group))
func run_for(s: Dictionary, seconds: float, c: Dictionary) -> Array:
	var out: Array=[]
	for i in int(ceil(seconds*30.0)): out.append_array(State.advance(s,src,1.0/30.0,c))
	return out
func soul(e: Array) -> int:
	var total:=0
	for x in of(e,"shared"):
		if str(x.name)=="GV_LUTHERS_SOUL": total+=int(x.value)
	return total

func run() -> void:
	src=State.source()
	var by_group:={}
	for r in src.records: by_group[int(r.group)]=r
	if not check(by_group[25628].commands==["021070000600","c60000002701","ce00000000ff","020100002700","c60000001403","0810700007000000","081070000a000100","101070000500"],"Kill 112 bytes"): return
	if not check(by_group[25802].commands==["02107b000600","c60000002701","1003ec010500","ce00000000ff","14107b000d0150810a14","020100002700","c60000001402","08107b0007000000","08107b000a000100","10107b000500"],"Kill 123 bytes"): return
	if not check(src.not_hosted.gate_leaves.has("78") and int(src.not_hosted.gate_leaves["78"].mask0)==0x0800 and not src.records.any(func(r): return str(r.owner_kind)=="movable"),"Gate leaves must stay unhosted"): return
	if not check(int(src.hits["112"].threshold)==1 and int(src.hits["123"].mode)==1 and bool(src.hits["123"].one_shot),"Hit contract"): return
	# ---- first meeting --------------------------------------------------------------------------------------------
	var s:=State.initial(src)
	if not check(State.validate(s,src).is_empty() and not s.controls["112"].present and not s.controls["123"].present,"Initial absent: %s"%State.validate(s,src)): return
	if not check(groups(State.sight(s,src,1465,ctx(0))).is_empty() and not s.controls["123"].present,"Unknown Daniel must not link"): return
	var e:=State.sight(s,src,1465,ctx())
	if not check(groups(e)==[15632] and s.controls["123"].present and int(s.controls["123"].segment)==3 and int(s.controls["123"].passes)==255,"Barrel sight: %s"%[groups(e)]): return
	e=State.enter_region(s,src,3408,ctx())
	if not check(groups(e)==[6852] and int(s.locals["20"])==1 and State.speaking(s)=="123" and of(e,"reposition").size()==1 and s.controls["123"].focus,"Region3408 start: %s"%[groups(e)]): return
	e=run_for(s,1.4,ctx())
	if not check(25734 in groups(e) and int(s.controls["123"].segment)==0 and (int(s.timers["68"][0].flags)&1)==0,"Conversation start: %s"%[groups(e)]): return
	run_for(s,5,ctx())
	var saved=JSON.parse_string(JSON.stringify(s))
	if not check(State.validate(saved,src).is_empty(),"Mid save: %s"%State.validate(saved,src)): return
	var t:=State.canonical(saved)
	var all_s: Array=[]
	for i in 30*30:
		var a:=State.advance(s,src,1.0/30.0,ctx());var b:=State.advance(t,src,1.0/30.0,ctx())
		if not check(groups(a)==groups(b),"Restored copy diverged at %d"%i): return
		all_s.append_array(a)
	if not check(260 in groups(all_s) and 25764 in groups(all_s) and int(s.locals["27"])==1 and State.speaking(s)=="" and not s.controls["123"].present,"Conversation end: %s"%[groups(all_s)]): return
	if not check(groups(State.enter_region(s,src,3397,ctx()))==[6840] and int(s.locals["20"])==2,"Region3397 local20"): return
	if not check(groups(State.enter_region(s,src,3408,ctx())).is_empty(),"Region3408 without Anyar/smoke"): return
	# ---- second meeting (talk) ------------------------------------------------------------------------------------
	var talk: Dictionary=State.canonical(s.duplicate(true))
	e=State.sight(talk,src,492,ctx(1,0,1))
	if not check(groups(e)==[10380] and talk.controls["112"].present and int(talk.props["492"].owner_state)==1 and int(talk.controls["112"].segment)==3,"Prop492 sight: %s"%[groups(e)]): return
	e=State.enter_region(talk,src,3408,ctx(1,0,1))
	if not check(groups(e)==[6906] and int(talk.locals["20"])==3 and State.speaking(talk)=="112","Second start: %s"%[groups(e)]): return
	e=run_for(talk,50,ctx(1,0,1))
	if not check(25556 in groups(e) and 25584 in groups(e) and soul(e)==1 and State.speaking(talk)=="" and not talk.controls["112"].present and int(talk.locals["39"])==0,"Second conversation: %s"%[groups(e)]): return
	# ---- kill 112 while idling ------------------------------------------------------------------------------------
	var k112: Dictionary=State.canonical(s.duplicate(true))
	State.sight(k112,src,492,ctx(1,0,1))
	# Mode1 threshold (context +0x1E >= 1; native replay village_dispatch): 0 or negative changes nothing, one-shot kept.
	var before:=JSON.stringify(k112)
	if not check(State.hit(k112,src,112,ctx(1,0,1),0).is_empty() and State.hit(k112,src,112,ctx(1,0,1),-5).is_empty() and JSON.stringify(k112)==before,"Rejected hit mutated state"): return
	e=State.hit(k112,src,112,ctx(1,0,1),1)
	if not check(groups(e)==[25628] and int(k112.locals["39"])==1 and int(k112.locals["20"])==3 and soul(e)==-1 and int(k112.controls["112"].segment)==1 and int(k112.controls["112"].owner_state)==5,"Kill 112: %s"%[groups(e)]): return
	if not check(State.hit(k112,src,112,ctx(1,0,1)).is_empty(),"One-shot hit"): return
	e=run_for(k112,2.5,ctx(1,0,1))
	if not check(25686 in groups(e) and not k112.controls["112"].present and of(e,"sound").any(func(x): return int(x.request)==227),"Kill 112 end: %s"%[groups(e)]): return
	if not check(groups(State.enter_region(k112,src,3408,ctx(1,0,1))).is_empty() and State.speaking(k112)=="","p175 after the kill"): return
	# ---- kill 123 at the first meeting ----------------------------------------------------------------------------
	var k123:=State.initial(src)
	State.sight(k123,src,1465,ctx())
	e=State.hit(k123,src,123,ctx())
	if not check(groups(e)==[25802] and int(k123.locals["39"])==1 and int(k123.locals["20"])==2 and int(k123.props["492"].owner_state)==5 and soul(e)==-1 and of(e,"sound").any(func(x): return int(x.request)==269),"Kill 123: %s"%[groups(e)]): return
	e=run_for(k123,2.5,ctx())
	if not check(25876 in groups(e) and not k123.controls["123"].present,"Kill 123 end"): return
	if not check(groups(State.sight(k123,src,492,ctx(1,0,1))).is_empty() and not k123.controls["112"].present,"Prop492 after killing 123"): return
	if not check(State.validate(JSON.parse_string(JSON.stringify(k123)),src).is_empty(),"Post-kill save"): return
	# ---- silent-speaker adapter -----------------------------------------------------------------------------------
	var silent:=State.initial(src)
	e=State.enter_region(silent,src,3408,ctx())
	if not check(State.speaking(silent)=="123" and int(silent.controls["123"].segment)==3 and 15632 in groups(e),"Hold must start the sighted idle: %s"%[groups(e)]): return
	var stuck:=State.initial(src)
	var c:=ctx();c.shared["25"]=0
	# local20==0 and Daniel known start the hold; a smoked hut (local6==1) blocks p198 itself, so force the case with p96
	# failing: prop1465 already in a non-zero state.
	stuck.props["1465"].owner_state=1
	e=State.enter_region(stuck,src,3408,c)
	if not check(State.speaking(stuck)=="" and of(e,"hold").any(func(x): return not x.value) and "adapter:release_silent_123" in stuck.receipts,"Silent hold must release: %s"%[e]): return
	# ---- malformed ------------------------------------------------------------------------------------------------
	var bad:=State.initial(src);bad.locals["39"]=-1
	if not check(not State.validate(bad,src).is_empty(),"Bad local accepted"): return
	bad=State.initial(src);bad.controls["112"].segment=1
	if not check(not State.validate(bad,src).is_empty(),"Absent speaker accepted"): return
	bad=State.initial(src);bad.controls["123"].present=true;bad.controls["112"].present=true;bad.controls["123"].hold=true;bad.controls["112"].hold=true
	if not check(not State.validate(bad,src).is_empty(),"Double hold accepted"): return
	print("PASS confidante state: first meeting, Met_Confidant timer/end, second meeting Soul+1, kills set Killed_Confidante once, gate leaves unhosted")
	quit(0)
