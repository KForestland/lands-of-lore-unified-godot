extends SceneTree
const Charger = preload("res://scripts/lol2/act2_charger_state.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Save = preload("res://scripts/lol2/act2_save.gd")
const INPUT := "~/AI_COMMS/act1_completion_20261017/r12w_qualification/campaign/userdata/act1_dark_halls_darker_arrival.json"
var failures := 0
func check(ok: bool, why: String):
 if not ok: failures+=1; printerr("FAIL charger: ",why)
func _initialize(): run.call_deferred()
func run():
 # Unit fixture: two source placement identities; NOT earned pickup/route evidence.
 var inventory: Array = ["act2:L10_DC:item8","act2:L10_DC:item9"]
 var collected := inventory.duplicate()
 var state := Charger.initial()
 var source := Save.read_save(INPUT,"lol2-restoration-darker-jungle")
 check(source.error.is_empty(),"base save validates")
 var packet: Dictionary = source.state
 var path := "res://tmp/act2_charger_state_save.json"
 check(not Charger.act(state,inventory,"L10:yellow","insert","wrong").ok,"wrong item refused")
 for item in collected:
  var result := Charger.act(state,inventory,"L10:yellow","insert",item)
  check(result.ok,"insert empty globe")
  if not result.ok: quit(1); return
  check(result.item_route.hosted and result.item_route.definition==98 and result.item_route.handler==0,"empty globe ordinary handler0 dispatch")
  state=result.state; inventory=result.inventory
  check(item not in inventory,"occupied globe removed from carried list")
  check(not Charger.act(state,inventory,"L10:yellow","insert",collected[1]).ok,"occupied slot refused")
  packet.quests.act2_chargers=state
  packet.quests.act2_items={"version":1,"carried":inventory,"collected":collected}
  var error := Save.write_save(path,packet,"lol2-restoration-darker-jungle")
  check(error.is_empty(),"occupied save: "+error)
  var loaded := Save.read_save(path,"lol2-restoration-darker-jungle")
  check(loaded.error.is_empty(),"occupied reload")
  if not loaded.error.is_empty(): quit(1); return
  state=loaded.state.quests.act2_chargers
  inventory=loaded.state.quests.act2_items.carried
  var full: Array=[]
  for i in 64: full.append("unit-capacity:%d" % i)
  var before := state.duplicate(true)
  check(not Charger.act(state,full,"L10:yellow","retrieve").ok and state==before,"full retrieval refuses without losing globe")
  result=Charger.act(state,inventory,"L10:yellow","retrieve")
  check(result.ok,"retrieve charged globe")
  state=result.state;inventory=result.inventory
  var output: String=item+":charged:yellow"
  check(inventory.count(output)==1 and Catalog.generic_index(output)==99,"unique charged identity maps original yellow definition99")
  check(not Charger.act(state,inventory,"L10:yellow","retrieve").ok,"duplicate retrieve refused")
  packet.quests.act2_chargers=state
  packet.quests.act2_items={"version":1,"carried":inventory,"collected":collected}
  check(Save.write_save(path,packet,"lol2-restoration-darker-jungle").is_empty(),"retrieved save")
 check(inventory.size()==2 and inventory[0]!=inventory[1],"two successive globes remain distinct")
 var bad := packet.duplicate(true)
 bad.quests.act2_items.carried.append(collected[0])
 check(not Save.validate(bad,"lol2-restoration-darker-jungle").is_empty(),"empty plus charged duplicate instance rejected")
 bad=packet.duplicate(true)
 bad.quests.act2_chargers.slots["invented"]=bad.quests.act2_chargers.slots["L10:yellow"].duplicate(true)
 check(not Save.validate(bad,"lol2-restoration-darker-jungle").is_empty(),"unknown charger rejected on load")
 bad=packet.duplicate(true)
 bad.quests.act2_items="malformed"
 check(not Save.validate(bad,"lol2-restoration-darker-jungle").is_empty(),"malformed item packet refused without exception")
 DirAccess.remove_absolute(path)
 for target in Charger.TARGETS:
  var empty:="act2:L10_DC:item8"
  var inserted:=Charger.act(Charger.initial(),[empty],target,"insert",empty)
  check(inserted.ok and inserted.item_route.definition==98,"ordinary empty globe accepted at "+target)
  var retrieved:=Charger.act(inserted.state,inserted.inventory,target,"retrieve")
  check(retrieved.ok and retrieved.inventory==[empty+":charged:"+Charger.TARGETS[target]],"exact single charged output at "+target)
 if failures==0:print("PASS charger transaction/catalog/actual save contracts; unit fixtures, production anchors/earned route NOT qualified")
 quit(0 if failures==0 else 1)
