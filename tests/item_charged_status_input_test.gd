extends "res://tests/item_consumables_input_test.gd"
const FIRE:="jungle:magic_shop:Fire_crystals_1"
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 if not await grant_scrolls([FIRE]):return
 var mana:int=scene.starting_magic.magic_state().player.mana
 for n in 4:
  if not await use_food(FIRE):return
  if not require(scene.item_effects.crystal_charges(FIRE)==3-n and scene.starting_magic.magic_state().player.mana==mana,"Actual right use spends exactly one native shop charge, no mana"):return
 if not await use_food(FIRE):return
 if not require(is_instance_valid(scene.inventory) and scene.inventory.detail_text.text.contains("Nothing happens") and scene.carried_collected.count(FIRE)==1 and scene.item_effects.crystal_charges(FIRE)==0,"Fifth use refused, burnt identity retained"):return
 await tap(KEY_ESCAPE);await tap(KEY_I);await frames(2)
 var list:ItemList=scene.inventory.item_list
 for i in list.item_count:
  if str(list.get_item_metadata(i))==FIRE:
   await button(MOUSE_BUTTON_LEFT,list.get_global_transform_with_canvas()*list.get_item_rect(i).get_center());break
 if not require(scene.inventory.detail_text.text.contains("Charges: 0") and scene.inventory.detail_text.text.contains("Burnt out"),"Actual inventory explains saved charge count"):return
 await picture("charged_burnt");await tap(KEY_ESCAPE)
 if not await disk_cycle("charged_status"):return
 if not require(scene.item_effects.crystal_charges(FIRE)==0 and scene.carried_collected.count(FIRE)==1,"F5/F9 preserves burnout"):return
 print("PASS actual I/right four known shop fire charges, fifth refusal, explicit count/burnout and F5/F9; no invented placed-crystal charges")
 quit()
