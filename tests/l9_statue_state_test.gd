extends SceneTree
const S=preload("res://scripts/lol2/l9_statue_state.gd")
var failures:=0
func check(ok: bool,why: String):
 if not ok:failures+=1;print("FAIL statue bowl: ",why)
func _initialize():
 var saved:=S.initial();var inventory: Array=[S.REMAINS,"reserved"]
 check(S.validate(saved,inventory).is_empty(),"initial state")
 check(not S.offer(saved,inventory,S.REMAINS).ok,"visit admission")
 saved.visited=true
 check(not S.offer(saved,inventory,"reserved").ok,"wrong item refusal")
 var r:=S.offer(saved,inventory,S.REMAINS)
 check(r.ok and inventory==[S.REMAINS,"reserved"] and saved.slots.is_empty(),"atomic Kit transaction")
 check(S.offered(r.state) and r.inventory==["reserved"],"exact remains consumed once")
 check(S.validate(JSON.parse_string(JSON.stringify(r.state)),r.inventory).is_empty(),"receipt JSON roundtrip")
 check(not S.offer(r.state,r.inventory,S.REMAINS).ok,"duplicate offering refused")
 check(not S.validate(r.state,inventory).is_empty(),"cannot carry an occupied remains instance")
 var bad: Dictionary=r.state.duplicate(true);bad.slots[S.TARGET].receipts=[]
 check(not S.validate(bad).is_empty(),"receipt required")
 if failures==0:print("PASS statue Kit visit/wrong/atomic/duplicate/JSON/occupied-instance validation")
 quit(0 if failures==0 else 1)
