extends SceneTree
const S=preload("res://scripts/lol2/l10_emperor_state.gd")
var failures:=0
func check(ok: bool,why: String):
 if not ok:failures+=1;print("FAIL Emperor: ",why)
func _initialize():
 var colors:={"125":"act2:L10_DC:item9:charged:blue","126":"act2:L10_DC:item43:charged:yellow","127":"act2:L10_DC:item8:charged:white"}
 for order in [["126","127","125"],["126","125","127"],["125","126","127"],["125","127","126"],["127","126","125"],["127","125","126"]]:
  var saved:=S.initial();var inventory: Array=colors.values()+[S.Ankh.ANKH,S.BRACERS]
  check(not S.act(saved,inventory,S.INNER,S.Ankh.ANKH).ok,"inner requires full set")
  for id in order:
   check(not S.act(saved,inventory,id,S.Ankh.ANKH).ok,"wrong item refused")
   var r:=S.act(saved,inventory,id,colors[id]);check(r.ok,"matching colour")
   saved=r.state;inventory=r.inventory
   check(S.validate(JSON.parse_string(JSON.stringify(saved)),inventory).is_empty(),"partial set roundtrip")
  check(S.count(saved)==3,"every order completes set")
  var r:=S.act(saved,inventory,S.INNER,S.Ankh.ANKH);check(r.ok and S.opened(r.state),"inner ankh opens")
  saved=r.state;inventory=r.inventory
  var removed:=S.act(saved,inventory,"126");check(removed.ok and not S.opened(removed.state),"removal closes")
  check(not S.take(removed.state,removed.inventory).ok,"incomplete set refuses remains")
  r=S.act(removed.state,removed.inventory,"126",colors["126"]);saved=r.state;inventory=r.inventory
  check(S.opened(saved),"replacement restores completed set")
  check(not S.take(saved,inventory,inventory.size()).ok,"capacity refusal")
  var no_bracers:=inventory.duplicate();no_bracers.erase(S.BRACERS)
  check(not S.take(saved,no_bracers).ok,"bracers required")
  r=S.take(saved,inventory);check(r.ok and S.REMAINS in r.inventory and not S.take(r.state,r.inventory).ok,"once-only remains")
  check(S.validate(r.state,r.inventory).is_empty(),"final state valid")
 if failures==0:print("PASS all six Emperor orders, Kit partial save/removal/replacement, inner ankh, bracers/full/duplicate reward guards")
 quit(0 if failures==0 else 1)
