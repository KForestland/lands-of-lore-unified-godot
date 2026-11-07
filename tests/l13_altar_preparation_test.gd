extends SceneTree
const Save=preload("res://scripts/lol2/act2_save.gd")
const Altar=preload("res://scripts/lol2/l13_altar_state.gd")
func _initialize():call_deferred("run")
func run():
 var path:="res://tmp/l13_bridge_qualified_save.json"
 if FileAccess.get_sha256(path)!="5340ed14935bd51506533cfdcbeadafe58f9de3b59a739dcbf34cc6dea0b6875":push_error("Missing qualified bridge input");quit(1);return
 var result=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not result.error.is_empty():push_error(result.error);quit(1);return
 var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var inventory:Array=raw.inventory.collected.duplicate();inventory.append_array(raw.quests.act2_items.carried)
 var before:=inventory.duplicate();var s:=Altar.initial();var saved:=s.duplicate(true)
 var dead:bool=float(raw.quests.act2_creatures_L13_RC.actors["40"].health)<=0
 if dead:push_error("This guard witness requires the actual living boss");quit(1);return
 for item in inventory:
  if Altar.enchant(s,inventory,item,str(raw.inventory.equipped_item),dead).ok:push_error("Live boss admitted sword enchantment");quit(1);return
 if Altar.take_stone(s,inventory,dead).ok or inventory!=before or s!=saved:push_error("Premature stone/mutation");quit(1);return
 print("PASS actual earned inventory/living boss refuses altar and stone without mutations; positive contract/world binding UNQUALIFIED")
 quit(0)
