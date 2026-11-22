extends "res://tests/item_consumables_input_test.gd"
const WEAPON:="act2:L10_DC:item32"
const ARMOR:="act2:L14_HT:item71"
const SHIELD:="act2:L13_RC:item145"
const RING:="act2:L10_DC:item33"
const GREATER:="act2:L12_CM:item4"
const THIRD:="act2:L20_BB:item0"
func equip_click(id:String)->bool:
 if not is_instance_valid(scene.inventory):await tap(KEY_I);await frames(3)
 if not require(is_instance_valid(scene.inventory) and paused,"Real I opens equipment inventory"):return false
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:index=i;break
 if not require(index>=0,"Genuine source identity visible in pack"):return false
 var at:Vector2
 for scroll in 60:
  at=list.get_global_transform_with_canvas()*(list.get_item_rect(index).get_center()-Vector2(0,list.get_v_scroll_bar().value))
  if list.get_global_rect().grow(-3).has_point(at):break
  await button(MOUSE_BUTTON_WHEEL_DOWN,list.get_global_rect().get_center());await frames(1)
 await button(MOUSE_BUTTON_LEFT,at);await frames(2)
 var detail:String=scene.inventory.detail_text.text
 var weapon:bool=scene.item_effects.Catalog.slot(id)=="weapon"
 if not require(not scene.inventory.equip_button.disabled and detail.count("Protection")==1 and detail.contains("Fixed damage:")==weapon,"Actual equipment detail has one Protection line and damage only for a weapon"):return false
 await button(MOUSE_BUTTON_LEFT,scene.inventory.equip_button.get_global_rect().get_center());await frames(2)
 return true
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 if not await grant_scrolls([WEAPON,ARMOR,SHIELD,RING,GREATER,THIRD]):return
 for id:String in [WEAPON,ARMOR,SHIELD,RING,GREATER]:
  if not await equip_click(id):return
 if not require(scene.equipped_item==WEAPON and scene.equipped_armor==ARMOR and scene.item_effects.state().offhand==SHIELD and scene.item_effects.accessories()==[RING,GREATER],"Actual clicks equip weapon/armor/shield/two accessories"):return
 var Defense=preload("res://scripts/lol2/player_defense.gd")
 if not require(Defense.scalar(scene)==50 and preload("res://scripts/lol2/player_combat.gd").damage(scene,true)==8,"Original30+5+5+10 protection and flat8 weapon, no balancing"):return
 if not await equip_click(THIRD):return
 if not require(scene.item_effects.accessories()==[RING,GREATER] and THIRD in scene.carried_collected,"Full accessory slots refuse replacement without losing item"):return
 # Worn-slot button is actual UI input, not a direct equipment callback.
 await button(MOUSE_BUTTON_LEFT,scene.inventory.equipment_slots[1].get_global_rect().get_center());await frames(2)
 if not require(scene.item_effects.accessories()==["",GREATER],"Real worn-slot click unequips first accessory"):return
 if not await equip_click(THIRD):return
 if not require(scene.item_effects.accessories()==[THIRD,GREATER] and Defense.scalar(scene)==45,"Zero-protection ring remains zero, source numbers unchanged"):return
 await picture("fixed_equipment");await tap(KEY_ESCAPE)
 if not await disk_cycle("fixed_equipment"):return
 print("EQUIP_RELOAD_DIAGNOSTIC weapon=",scene.equipped_item," armor=",scene.equipped_armor," offhand=",scene.item_effects.state().get("offhand")," accessories=",scene.item_effects.accessories()," defense=",Defense.scalar(scene)," carried=",scene.carried_collected," side=",scene.quest_state.get("act2_items"))
 if not require(scene.equipped_item==WEAPON and scene.equipped_armor==ARMOR and scene.item_effects.state().offhand==SHIELD and scene.item_effects.accessories()==[THIRD,GREATER] and Defense.scalar(scene)==45,"F9 keeps all five slots and protection"):return
 const Slots=preload("res://scripts/lol2/game_save.gd")
 var saved:Dictionary=Slots.read_document(Slots.slot_path(1)).state.area_save
 for id:String in [WEAPON,ARMOR,SHIELD,THIRD,GREATER]:
  if not require(id in saved.inventory.collected and id not in saved.quests.act2_items.carried,"Worn world identity is validated once in existing slot inventory"):return
 if not require(RING in saved.quests.act2_items.carried and RING not in saved.inventory.collected,"Unequipped world identity retains its original side-bank placement"):return
 print("PASS actual inventory clicks weapon/armor/shield/two accessories, fixed original protection+flatdamage, full/unequip/zero ring, F5/F9 exact equipped ownership; F08genuine grants/NPC fixtures, no teleport")
 quit()
