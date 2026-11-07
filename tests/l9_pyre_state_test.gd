extends SceneTree
const State=preload("res://scripts/lol2/l9_pyre_state.gd")
var failures:=0
func check(ok: bool,message: String):
 if not ok:failures+=1;print("FAIL pyre state: ",message)
func _initialize():
 var initial:=State.initial();check(State.validate(initial).is_empty(),"initial valid")
 for phase in [-1,0.5,4]:
  var bad:=initial.duplicate(true);bad.phase=phase;check(not State.validate(bad).is_empty(),"invalid phase refused")
 var bad:=initial.duplicate(true);bad.body[0]=INF;check(not State.validate(bad).is_empty(),"nonfinite body refused")
 bad=initial.duplicate(true);bad.phase=1;check(not State.validate(bad).is_empty(),"placed body needs Kit receipt")
 check(not State.place_body(initial,[10884.828369,140,-12566.17163]).ok,"cannot place an unheld world body")
 var held:=initial.duplicate(true);held.holding=true
 var result:=State.place_body(held,[10884.828369,140,-12566.17163]);check(result.ok and held.phase==0 and held.holding,"pure body transaction preserves input")
 var placed: Dictionary=result.state;check(State.validate(placed).is_empty(),"placed Kit receipt valid")
 bad=placed.duplicate(true);bad.phase=3;bad.burn=State.DURATION;check(not State.validate(bad).is_empty(),"ashes require both source orbs")
 bad.orbs=["1205","1205"];check(not State.validate(bad).is_empty(),"duplicate source orb refused")
 var ashes:=placed.duplicate(true);ashes.orbs=["1205","1206"];ashes.phase=3;ashes.burn=State.DURATION
 var inventory: Array=[State.URN,"reserved"]
 check(not State.act(ashes,inventory,"insert","reserved").ok and inventory==[State.URN,"reserved"],"wrong item refused without loss")
 result=State.act(ashes,inventory,"insert",State.URN)
 check(result.ok and result.item_route.hosted and result.item_route.handler==0 and result.item_route.definition==78,"caretaker urn ordinary handler0 dispatch")
 check(result.ok and inventory==[State.URN,"reserved"] and ashes.slots.size()==1,"pure urn commit preserves inputs")
 var occupied: Dictionary=result.state
 check(State.validate(JSON.parse_string(JSON.stringify(occupied))).is_empty(),"occupied receipt JSON roundtrip")
 check(not State.act(occupied,result.inventory,"retrieve","",1).ok,"capacity refusal keeps occupied output")
 var taken:=State.act(occupied,result.inventory,"retrieve")
 check(taken.ok and taken.item_route.hosted and taken.item_route.handler==0 and taken.item_route.definition==168,"full urn ordinary handler0 dispatch")
 check(taken.ok and taken.inventory==["reserved",State.FULL],"unique original full urn output")
 check(not State.act(taken.state,taken.inventory,"retrieve").ok,"no duplicate retrieve")
 if failures==0:print("PASS pyre phase/orb/Kit receipt validation, atomic body/urn transactions, JSON/full/refusal")
 quit(0 if failures==0 else 1)
