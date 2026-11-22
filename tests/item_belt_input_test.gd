extends "res://tests/item_consumables_input_test.gd"
## Actual inventory context menu, F, wheel/brackets, target hint/E and slot reload.
func belt_menu(id:String)->bool:
 await tap(KEY_I);await frames(3)
 if not require(is_instance_valid(scene.inventory),"Actual I inventory"):return false
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:index=i;break
 if not require(index>=0,"Item is in real grid"):return false
 await button(MOUSE_BUTTON_RIGHT,list.get_global_transform_with_canvas()*list.get_item_rect(index).get_center())
 await frames(2)
 var menu:PanelContainer=scene.inventory.item_menu
 if not require(is_instance_valid(menu) and menu.visible and menu.get_node("Choices/PutOnBelt").text=="Put on belt","Real right click offers Put on belt without consumption"):return false
 # Native popup menu receives real keyboard focus/Enter; no callback invocation.
 await button(MOUSE_BUTTON_LEFT,menu.get_node("Choices/PutOnBelt").get_global_rect().get_center());await frames(3)
 if not require(scene.item_effects.Catalog.definition(id) in scene.item_effects.belt_state().slots and id in scene.carried_collected,"Actual context action assigns an owned reference"):return false
 await tap(KEY_ESCAPE)
 return true
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 const EMPTY:="act2:L10_DC:item44"
 if not await grant_scrolls([SPARE,EMPTY]):return
 scene.quest_state.jungle_world_items={"version":1,"collected":[63]} # Disclosed original receipt for the free Aloe instance.
 await frames(12)
 var value:Dictionary=scene.item_effects.belt_state()
 if not require(98 in value.slots and not 91 in value.slots,"Quest globe autopickup, optional food stays in pack"):return
 if not await belt_menu(SPARE):return
 await tap(KEY_BRACKETRIGHT);await frames(12)
 var active:String=preload("res://scripts/lol2/item_belt_state.gd").resolve(value,int(value.active),scene.carried_collected)
 if not require(active==SPARE,"Actual right bracket skips empty slots onto Aloe"):return
 scene.starting_magic.set_health(10)
 await tap(KEY_F);await ticks(180)
 if not require(SPARE not in scene.carried_collected and scene.starting_magic.health()>=15,"Real F consumes owned Aloe and heals"):return
 if not await grant_scrolls(["act2:L13_RC:item53"]):return
 if not await belt_menu("act2:L13_RC:item53"):return
 var charger:Node=scene.get_node("Act2Chargers")
 if not await stand_at(Vector3(1153,-125,-3553)):return
 if not await look(charger.globes["L10:yellow"].global_position):return
 await frames(12)
 if not require(scene.item_effects.smart_item==EMPTY and preload("res://scripts/lol2/item_belt_state.gd").resolve(value,int(value.active),scene.carried_collected)==EMPTY and EMPTY in scene.carried_collected and not charger.globes["L10:yellow"].visible,"Aim rolls to carried empty globe/glow/hint, never auto-uses"):return
 await picture("belt_smart_globe")
 await button(MOUSE_BUTTON_WHEEL_DOWN,Vector2(640,360));await frames(3)
 if not require(preload("res://scripts/lol2/item_belt_state.gd").resolve(value,int(value.active),scene.carried_collected)!=EMPTY,"Real wheel selected a different active item before E"):return
 var before:Array=scene.carried_collected.duplicate()
 await tap(KEY_E)
 if not require(EMPTY in before and EMPTY not in scene.carried_collected and charger.globes["L10:yellow"].visible,"Real E uses the carried fitting globe even after rolling to a different active item"):return
 await tap(KEY_E);await frames(12)
 var charged:String=EMPTY+":charged:yellow"
 if not require(charged in scene.carried_collected and 99 in value.slots,"Actual retrieval automatically belts charged globe"):return
 # A real missing-item refusal remains a hard negative control. A charged
 # globe and a Dreamstone cannot substitute for the altar's EMPTY globe.
 before=scene.carried_collected.duplicate()
 var charger_before:Dictionary=charger.state().duplicate(true)
 await tap(KEY_E);await frames(4)
 if not require(scene.carried_collected==before and charger.state()==charger_before and not charger.globes["L10:yellow"].visible and scene.interface_hud.hint.text=="The charger requires an empty glass globe.","Without a fitting carried item, real E names the needed item and consumes nothing"):return
 var saved:Dictionary=value.duplicate(true)
 if not await disk_cycle("belt_saved"):return
 if not require(scene.item_effects.belt_state()==saved,"F5/F9 preserves five slots, ages and active selection exactly"):return
 print("PASS belt real I/right/menu/Enter/F Aloe, actual wheel/brackets, aimed globe auto-roll/no-autouse, nonactive carried E charge/retrieve, missing empty globe refusal atomic, F5F9; disclosed component aids")
 quit()
