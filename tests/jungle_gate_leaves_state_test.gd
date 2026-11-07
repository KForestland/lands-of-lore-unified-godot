extends SceneTree
## Village gate-leaf consumer on the pure state (explicitly supplied hit contexts; not an input or route proof).
## Contract (VILLAGE_ESCAPE_CONTRACT groups 28068/28140; Codex gate_movable_binding durability5, gate_level_binding
## level4): mask0 0x0800, threshold1, mode4, predicate196 (local39==1 AND shared29==1), commands sound452/link/unlink.
## - Rejections change nothing: predicate (no kill, no alert), mask (0x0400, 0), durability (after 2, 5), malformed context.
## - Leaf78 accepted: sound452 at control81, control81 linked, leaf78 unlinked; leaf79 untouched and accepted on its own.
## - A second context on an unlinked leaf is refused; JSON save round trip and pairing validation; source relink regions
##   (588/3895/3896/3897) relink both leaves and unlink both fallen leaves.
const State=preload("res://scripts/lol2/jungle_gate_leaves_state.gd")
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func ctx(killed: int, alert: int) -> Dictionary: return {"locals":{"39":killed},"shared":{"29":alert}}
func run() -> void:
	var src:=State.source()
	for l in ["78","79"]:
		var row: Dictionary=src.leaves[l]
		if not check(int(row.mask0)==0x0800 and int(row.mask1)==0 and int(row.threshold)==1 and int(row.mode)==4 and int(row.predicate)==196 and int(row.durability)==5 and not bool(row.one_shot),"Leaf %s contract"%l): return
	if not check(src.leaves["78"].commands==["14105100c401fa000a14","091051000300","09204e000200"] and src.leaves["79"].commands==["14105100c40180000a14","091050000300","09204f000200"] and int(src.level_index)==4,"Leaf commands"): return
	var s:=State.initial(src)
	if not check(State.validate(s,src).is_empty() and s.leaves["78"] and s.leaves["79"] and not s.controls["80"] and not s.controls["81"],"Initial links"): return
	var good:={"mask0":0x0800,"before":5,"after":0}
	var before:=JSON.stringify(s)
	for case in [[good,ctx(0,1),"predicate"],[good,ctx(1,0),"predicate"],[{"mask0":0x0400,"before":5,"after":0},ctx(1,1),"mask"],[{"mask0":0,"before":5,"after":0},ctx(1,1),"mask"],
			[{"mask0":0x0800,"before":5,"after":2},ctx(1,1),"durability"],[{"mask0":0x0800,"before":5,"after":5},ctx(1,1),"durability"],[{"mask0":0x0800,"before":5},ctx(1,1),"invalid context"],[{"mask0":0x0800,"before":5,"after":0.5},ctx(1,1),"invalid context"]]:
		var why:=State.refusal(s,src,78,case[0],case[1])
		if not check(why==case[2] and State.hit(s,src,78,case[0],case[1]).is_empty() and JSON.stringify(s)==before,"Rejected %s: %s"%[case,why]): return
	var e:=State.hit(s,src,78,{"mask0":0x0801,"before":5,"after":1},ctx(1,1))
	if not check(e.any(func(x): return x.type=="sound" and int(x.request)==452 and int(x.object)==81) and not s.leaves["78"] and s.controls["81"] and s.leaves["79"] and not s.controls["80"],"Leaf78 accepted: %s"%[e]): return
	if not check(State.refusal(s,src,78,good,ctx(1,1))=="leaf unlinked" and State.hit(s,src,78,good,ctx(1,1)).is_empty(),"Unlinked leaf accepted again"): return
	var saved=JSON.parse_string(JSON.stringify(s))
	if not check(State.validate(saved,src).is_empty() and State.canonical(saved)==s,"Save round trip"): return
	e=State.hit(s,src,79,good,ctx(1,1))
	if not check(not s.leaves["79"] and s.controls["80"] and not s.leaves["78"],"Leaf79 accepted independently"): return
	var bad:=State.initial(src);bad.controls["81"]=true
	if not check(not State.validate(bad,src).is_empty(),"Unpaired fallen leaf accepted"): return
	bad=State.initial(src);bad.leaves["78"]=1
	if not check(not State.validate(bad,src).is_empty(),"Non-boolean link accepted"): return
	e=State.enter_region(s,src,588)
	if not check(s.leaves["78"] and s.leaves["79"] and not s.controls["80"] and not s.controls["81"] and e.size()>0,"Relink region588"): return
	if not check(State.enter_region(s,src,588).is_empty() and State.enter_region(s,src,1234).is_empty(),"Relink repeats/unknown region"): return
	print("PASS gate leaves state: mask/durability/predicate rejection without change; leaf78/79 accepted independently with sound452 and control link; relink regions")
	quit(0)
