extends SceneTree
## Kityara follow-up on the pure state (supplied contexts; not a route).
## - Presence: a p150 link region shows her after translation even before the first meeting; p151 start needs Met.
## - Start (region1257): local21=1, hold, segment1, timer prop65 armed; the other location (870) cannot start again.
## - The 19 s timer raises prop65 event20: local41 and the definition29 grant exactly once; the segment1 end (g18022)
##   repeats local41/GV_LUTHER_HAS_WARBLADE writes and releases Luther without a second grant; idle loop afterwards.
## - Mid-conversation JSON save continues identically. Offers need exact identity (Power orb only without Firestorm).
## - Hit path: soul -1, GV_KITYARA_DEAD, death segment, leave, dropped knife prop64; using it grants once.
## - Unlink regions remove her; local21 prevents relinking. Malformed states are rejected.
const State=preload("res://scripts/lol2/jungle_kityara_state.gd")
var failed:=false
var src: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func ctx(met: int, translated: int=1, dead: int=0, firestorm: int=0) -> Dictionary:
	return {"locals":{"35":met,"54":firestorm,"23":0,"41":0},"shared":{"0":5,"14":translated,"20":0,"25":dead,"47":1}}
func of(e: Array, t: String) -> Array: return e.filter(func(x): return x.type==t)
func groups(e: Array) -> Array: return of(e,"group").map(func(x): return int(x.group))
func region_with(cmd: String, pred: Variant) -> int:
	for r in src.records:
		var same: bool=(r.predicate==null and pred==null) or (r.predicate!=null and pred!=null and int(r.predicate)==int(pred))
		if str(r.owner_kind)=="region" and cmd in r.commands and same: return int(r.owner)
	return -1
func run_for(s: Dictionary, seconds: float, c: Dictionary) -> Array:
	var out: Array=[]
	for i in int(ceil(seconds*30.0)): out.append_array(State.advance(s,src,1.0/30.0,c))
	return out

func run() -> void:
	src=State.source()
	var link150:=region_with("091000000300",150);var link151:=region_with("091000000300",151);var unlink:=region_with("091000000200",null)
	if not check(link150>0 and link151>0 and unlink>0 and src.start_regions.map(func(x): return int(x)).has(1257) and src.start_regions.map(func(x): return int(x)).has(870),"Source regions missing"): return
	var s:=State.initial(src)
	if not check(not s.controls["0"].present and not s.controls["83"].present and s.props["65"].present and not s.props["64"].present and State.validate(s,src).is_empty(),"Initial presence"): return
	# Not yet translated: nothing; translated but not met: she appears (p150) but no conversation starts.
	if not check(groups(State.enter_region(s,src,link150,ctx(0,0))).is_empty(),"Untranslated link"): return
	State.enter_region(s,src,link150,ctx(0))
	if not check(s.controls["0"].present and groups(State.enter_region(s,src,1257,ctx(0))).is_empty() and int(s.locals["21"])==0,"Unmet start must not run"): return
	# Earned meeting (supplied here): start.
	var e:=State.enter_region(s,src,1257,ctx(1))
	if not check(int(s.locals["21"])==1 and State.speaking(s)=="0" and int(s.controls["0"].segment)==1 and (int(s.timers["65"][0].flags)&1)==0 and of(e,"reposition").size()==1,"Start %s"%[groups(e)]): return
	if not check(groups(State.enter_region(s,src,870,ctx(1))).is_empty(),"Second location must not start"): return
	# Mid-conversation save, then both copies continue.
	run_for(s,5,ctx(1))
	var saved=JSON.parse_string(JSON.stringify(s))
	if not check(State.validate(saved,src).is_empty(),"Mid save: %s"%State.validate(saved,src)): return
	var t:=State.canonical(saved)
	var all_s: Array=[];var all_t: Array=[]
	for i in 30*40:
		var a:=State.advance(s,src,1.0/30.0,ctx(1));var b:=State.advance(t,src,1.0/30.0,ctx(1))
		if not check(groups(a)==groups(b),"Restored copy diverged at %d"%i): return
		all_s.append_array(a)
	var grants:=of(all_s,"grant")
	if not check(grants.size()==1 and int(grants[0].identity)==int(src.item.identity),"Knife must be granted exactly once: %s"%[grants]): return
	if not check(of(all_s,"shop_local").any(func(x): return x.name=="kityara_gave_knife" and x.value==1) and of(all_s,"shared").any(func(x): return x.name=="GV_LUTHER_HAS_WARBLADE" and x.value==1),"Knife local/global missing"): return
	if not check(State.speaking(s)=="" and int(s.props["65"].owner_state)==1 and int(s.controls["0"].segment)==0 and int(s.controls["0"].passes)>0 and int(s.controls["0"].owner_state)==1,"Release/idle after knife"): return
	if not check(of(run_for(s,30,ctx(1)),"grant").is_empty(),"Repeat grant"): return
	# Offers: exact identity, first eligible; Power orb only without Firestorm.
	if not check(State.offer(s,src,0,12345,ctx(1)).is_empty() and State.offer(s,src,0,2280794846,ctx(1,1,0,1)).filter(func(x): return x.type=="shop_local").is_empty(),"Offer gating"): return
	var o:=State.offer(s,src,0,2280794846,ctx(1))
	if not check(of(o,"shop_local").any(func(x): return x.name=="Kityara_Given_Orb") and of(o,"consume_held").size()==1 and int(s.controls["0"].segment)==2,"Orb offer"): return
	run_for(s,16,ctx(1))
	# Unlink region: she leaves; local21 prevents relinking.
	State.enter_region(s,src,unlink,ctx(1))
	if not check(not s.controls["0"].present and groups(State.enter_region(s,src,link150,ctx(1))).is_empty() and not s.controls["0"].present,"Leave/no relink"): return
	# Hit path on a fresh, present Kityara.
	var h:=State.initial(src);State.enter_region(h,src,link150,ctx(0))
	var hit:=State.hit(h,src,0,ctx(0))
	if not check(of(hit,"shared").any(func(x): return x.name=="GV_KITYARA_DEAD" and x.value==1) and of(hit,"shared").any(func(x): return x.name=="GV_LUTHERS_SOUL" and x.op=="add" and x.value==-1) and int(h.controls["0"].segment)==3,"Hit path %s"%[groups(hit)]): return
	run_for(h,6,ctx(0,1,1))
	if not check(not h.controls["0"].present and h.props["64"].present,"Death leave/drop"): return
	var drop:=State.use_prop(h,src,64,ctx(0,1,1))
	if not check(of(drop,"grant").size()==1 and int(h.props["65"].owner_state)==1 and of(State.use_prop(h,src,64,ctx(0,1,1)),"grant").is_empty(),"Dropped knife once"): return
	# Source pre-conversation death/drop leaves local21=0: valid, and it survives a disk round trip (both locations).
	for loc in [["0",64,"65"],["83",67,"66"]]:
		var d:=State.initial(src);var link:=-1
		for r in src.records:
			if str(r.owner_kind)=="region" and r.predicate!=null and int(r.predicate)==150 and ("091053000300" if loc[0]=="83" else "091000000300") in r.commands: link=int(r.owner);break
		State.enter_region(d,src,link,ctx(0))
		State.hit(d,src,int(loc[0]),ctx(0));run_for(d,6,ctx(0,1,1))
		var g:=State.use_prop(d,src,int(loc[1]),ctx(0,1,1))
		var round=JSON.parse_string(JSON.stringify(d,"",true,true))
		if not check(link>0 and of(g,"grant").size()==1 and int(d.locals["21"])==0 and int(d.props[loc[2]].owner_state)==1 and State.validate(d,src).is_empty() and State.validate(round,src).is_empty() and State.canonical(round)==d,"Death/drop at control%s: %s"%[loc[0],State.validate(d,src)]): return
	# A start region entered without crossing a presence region: the clip start makes her present; the save stays valid.
	var direct:=State.initial(src);State.enter_region(direct,src,870,ctx(1))
	if not check(direct.controls["83"].present and State.speaking(direct)=="83" and State.validate(direct,src).is_empty(),"Direct start: %s"%State.validate(direct,src)): return
	# Validation.
	var bad:=s.duplicate(true);bad.locals["21"]=2
	if not check(not State.validate(bad,src).is_empty(),"Bad local21 accepted"): return
	bad=s.duplicate(true);bad.controls["0"].segment=9
	if not check(not State.validate(bad,src).is_empty(),"Bad segment accepted"): return
	bad=s.duplicate(true);bad.controls["83"].hold=true
	if not check(not State.validate(bad,src).is_empty(),"Silent hold accepted"): return
	if not check(not State.validate({"version":1},src).is_empty(),"Empty state accepted"): return
	print("PASS jungle_kityara_state_test: presence/admission gates, one-time start, 19 s timer knife once, release/idle, mid save, offers, leave/no relink, hit/drop once, validation (supplied contexts)")
	quit(0)
