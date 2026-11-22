extends "res://tests/helpers/g15_stored_spell_input.gd"
## Component: genuine ids granted through F08, one disclosed stand; real I/right/E/F5/F9.
const EMPTY:="act2:L10_DC:item44"
func _initialize():main.call_deferred()
func select_target(id:String)->bool:
 await tap(KEY_I);await frames(3)
 if not require(is_instance_valid(scene.inventory) and paused,"Real I opens inventory"):return false
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:index=i;break
 if not require(index>=0,"Carried target item shown"):return false
 var before:Array=scene.carried_collected.duplicate()
 var at:Vector2
 for scroll in 60:
  at=list.get_global_transform_with_canvas()*(list.get_item_rect(index).get_center()-Vector2(0,list.get_v_scroll_bar().value))
  if list.get_global_rect().grow(-3).has_point(at):break
  await button(MOUSE_BUTTON_WHEEL_DOWN,list.get_global_rect().get_center());await frames(1)
 await button(MOUSE_BUTTON_RIGHT,at);await frames(4)
 await frames(2)
 if is_instance_valid(scene.inventory) and is_instance_valid(scene.inventory.item_menu):
  await button(MOUSE_BUTTON_LEFT,scene.inventory.item_menu.get_node("Choices/UseOnTarget" if not preload("res://scripts/lol2/player_stored_globes.gd").spell(id).is_empty() else "Choices/UseItem").get_global_rect().get_center())
 if is_instance_valid(scene.inventory):print("TARGET_SELECT_DIAGNOSTIC id=",id," index=",index," pointer=",at," list=",list.get_global_rect()," scroll=",list.get_v_scroll_bar().value," form=",scene.player_form," detail=",scene.inventory.detail_text.text)
 return require(not is_instance_valid(scene.inventory) and scene.hand_item==id and scene.carried_collected==before and id not in scene.item_effects.state().spent,"Real Use selects for E; does not consume or run target transaction")
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 var targets:Array=[EMPTY,"museum:control87:Sk_key","act2:L10_DC:item43"]
 if not await grant_scrolls(targets):return
 for id:String in targets:
  if not await select_target(id):return
 if not await select_target(EMPTY):return
 var charger:Node=scene.get_node("Act2Chargers")
 if not await stand_at(Vector3(1153,-125,-3553)):return
 if not await look(charger.globes["L10:yellow"].global_position):return
 await tap(KEY_E);await frames(4)
 if not require(EMPTY not in scene.carried_collected and charger.globes["L10:yellow"].visible,"Actual E performs existing globe-target transaction"):return
 if not await disk_cycle("world_item_target_occupied"):return
 charger=scene.get_node("Act2Chargers")
 if not await look(charger.globes["L10:yellow"].global_position):return
 await tap(KEY_E);await frames(4)
 var charged:String=EMPTY+":charged:yellow"
 if not require(scene.carried_collected.count(charged)==1,"Real E retrieves exactly one transformed identity"):return
 if not await select_target(charged):return
 await picture("world_item_target")
 print("PASS target selection real I/right three genuine identities, E charger place/retrieve, F5/F9 exact slot; no selection consumption, disclosed grant/NPC/stand component aids")
 quit()
