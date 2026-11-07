extends SceneTree
const S=preload("res://scripts/lol2/l10_ankh_state.gd")
var failures:=0
func check(ok: bool,why: String):
 if not ok:failures+=1;print("FAIL ankh: ",why)
func _initialize():
 var initial:=S.initial();var inv: Array=[S.FULL,"reserved"]
 check(not S.act(initial,inv,S.TRADE,"reserved").ok,"wrong item")
 var r:=S.act(initial,inv,S.TRADE,S.FULL)
 check(r.ok and r.item_route.hosted and r.item_route.definition==168 and r.item_route.handler==0,"filled urn ordinary handler0 dispatch")
 check(r.ok and inv==[S.FULL,"reserved"] and initial.slots.is_empty(),"atomic trade")
 check(S.validate(JSON.parse_string(JSON.stringify(r.state))).is_empty(),"occupied JSON")
 check(not S.act(r.state,r.inventory,S.TRADE,"",1).ok,"full retrieval")
 r=S.act(r.state,r.inventory,S.TRADE)
 check(r.ok and S.ANKH in r.inventory and S.FULL not in r.inventory,"retrieve ankh")
 check(not S.act(r.state,r.inventory,S.TRADE,S.FULL).ok,"no duplicate gift")
 r=S.act(r.state,r.inventory,S.SLAB,S.ANKH)
 check(r.ok and r.item_route.hosted and r.item_route.definition==97 and r.item_route.handler==0,"ankh ordinary handler0 dispatch")
 check(r.ok and S.committed(r.state,S.SLAB),"slab committed")
 r=S.act(r.state,r.inventory,S.SLAB)
 check(r.ok and S.ANKH in r.inventory and S.validate(r.state).is_empty(),"ankh retained")
 var bad: Dictionary=r.state.duplicate(true);bad.slots.erase(S.TRADE)
 check(not S.validate(bad).is_empty(),"reject unearned slab receipt")
 if failures==0:print("PASS Kit ashes/ankh/slab atomic occupied/full/duplicate/JSON/retained state")
 quit(0 if failures==0 else 1)
