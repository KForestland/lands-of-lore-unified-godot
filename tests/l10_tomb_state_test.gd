extends SceneTree
const State=preload("res://scripts/lol2/l10_tomb_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
var failures:=0
func check(ok: bool,why: String):
 if not ok:failures+=1;printerr("FAIL tomb state: ",why)
func _initialize():
 # Pure transaction vectors, never used to seed a gameplay save.
 var base:="act2:L10_DC:item44"
 for target in State.ROWS:
  var color: String={99:"yellow",100:"white",101:"blue"}[State.ROWS[target][1]]
  var id:=base+":charged:"+color
  var wrong:=base+":charged:"+("white" if color!="white" else "blue")
  var inventory: Array=[id,wrong,base,"sword-globe-decoy"]
  var before:=inventory.duplicate()
  var state:=State.initial()
  for refused in [wrong,base,"sword-globe-decoy","missing"]:
   check(not State.offer(state,inventory,target,refused).ok and inventory==before and state==State.initial(),"refusal atomic "+target+" "+refused)
  var result:=State.offer(state,[id],target,id)
  check(result.ok,"matching color "+target)
  if not result.ok:continue
  check(result.inventory.is_empty() and state==State.initial(),"consume once without input mutation")
  var quests: Dictionary={"act2_items":{"version":1,"carried":[],"collected":[base]}}
  check(State.validate(result.state,quests).is_empty(),"valid earned ownership")
  check(not State.offer(result.state,[id],target,id).ok,"committed slot rejects replay")
  quests.act2_items.carried=[id]
  check(not State.validate(result.state,quests).is_empty(),"spent globe cannot remain carried")
  quests.act2_items.carried=[];quests.act2_items.collected=[]
  check(not State.validate(result.state,quests).is_empty(),"unearned globe rejected")
  quests.act2_items.collected=[base]
  quests.act2_chargers={"slots":{"L10:yellow":{"occupied":id}}}
  check(not State.validate(result.state,quests).is_empty(),"spent globe cannot occupy charger")
 if failures==0:print("PASS all13 receptacle/color joins, wrong/empty/decoy refusal, atomic consume, replay and earned ownership validation; pure unit vectors")
 quit(0 if failures==0 else 1)
