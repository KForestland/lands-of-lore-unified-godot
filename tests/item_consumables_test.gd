extends SceneTree
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Foods=preload("res://scripts/lol2/item_consumables.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const State=preload("res://scripts/lol2/player_item_state.gd")
func _initialize():
 var ids:Array=Catalog.ids("world")
 for id in Items.all_ids():
  if id not in ids:ids.append(id)
 var checked:=0
 for id in ids:
  var definition:int=Catalog.definition(id)
  if Foods.kind(definition).is_empty():continue
  assert(Catalog.use_kind(id)==Foods.kind(definition),"Definition-wide dispatch differs on "+str(id))
  assert(id in Catalog.consumables(),"Saved consumed identity must be admitted: "+str(id))
  checked+=1
 var old:Dictionary=State.initial()
 assert(State.validate(old,[]).is_empty(),"Unchanged pre-food packet remains valid")
 old.mandrake_sleep=1.0
 assert(not State.validate(old,[]).is_empty(),"Sleep without consumed Mandrake is rejected")
 old.spent=["act2:L13_RC:item53"]
 assert(State.validate(old,[]).is_empty(),"Consumed genuine Mandrake admits a finite timer")
 for bad in [-1.0,6.0,INF,NAN,"5"]:
  old.mandrake_sleep=bad
  assert(not State.validate(old,[]).is_empty(),"Malformed timer rejected")
 old.mandrake_sleep=2.5
 old.spent.append("jungle:magic_shop:War_cluster")
 old.war_cluster={"remaining":60.0,"bonus":6}
 assert(State.validate(old,[]).is_empty(),"Genuine consumed cluster permits exact guide bonus/timer")
 assert(preload("res://scripts/lol2/player_health.gd").limit_from_effects(old)==36,"Active bonus permits36, old packets remain30")
 old.war_cluster.bonus=7
 assert(not State.validate(old,[]).is_empty(),"Invented bonus rejected")
 old.erase("war_cluster")
 old.mandrake_sleep=2.5
 assert(State.canonical(old).mandrake_sleep==2.5,"Canonical save keeps exact timer")
 print("PASS global consumables ",checked," identities; all finite source variants/consumption bounds, old-packet compatibility and malformed timer rejection")
 quit()
