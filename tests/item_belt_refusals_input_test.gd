extends "res://tests/item_consumables_input_test.gd"
func _initialize():main.call_deferred()
func values(mana:int,cooldown:float):
 var magic:Node=scene.starting_magic
 var saved:Dictionary=magic.magic_state().duplicate(true);saved.player.mana=mana;saved.cooldown=cooldown;magic.commit(saved)
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 const FIRST:="act2:L10_DC:item44:charged:yellow"
 const SECOND:="act2:L10_DC:item45:charged:yellow"
 const WHITE:="act2:L10_DC:item43:charged:white"
 const SCROLL:="act2:L10_DC:item21"
 if not await grant_scrolls([FIRST,SECOND,WHITE,SCROLL]):return
 scene.item_effects.put_on_belt(FIRST,int(scene.item_effects.belt_state().active));await frames(12)
 var original:Array=scene.carried_collected.duplicate()
 await tap(KEY_I);await frames(3);await tap(KEY_F)
 if not require(scene.carried_collected==original and paused,"Real F browsing inventory cannot cast or consume"):return
 await tap(KEY_ESCAPE)
 scene.starting_magic.set_process(false) # Explicit mana/cooldown refusal fixtures.
 values(0,0)
 await tap(KEY_F)
 if not require(scene.carried_collected==original and scene.interface_hud.hint.text=="Not enough mana","No-mana F keeps the globe and its real refusal"):return
 values(12,0.5)
 await tap(KEY_F)
 if not require(scene.carried_collected==original and scene.interface_hud.hint.text=="Wait a moment before casting again","Busy-cast F keeps globe and cooldown refusal"):return
 values(12,0)
 await tap(KEY_F)
 if not require(FIRST not in scene.carried_collected and "act2:L10_DC:item44" in scene.carried_collected,"Admitted F returns only its exact empty source"):return
 values(12,0)
 if not await use_food(SECOND):return
 if not require(SECOND not in scene.carried_collected and "act2:L10_DC:item45" in scene.carried_collected and not is_instance_valid(scene.inventory),"Actual inventory right/menu Use casts a charged globe and returns empty"):return
 values(12,0)
 if not await use_food(WHITE):return
 if not require(WHITE in scene.carried_collected and scene.starting_magic.magic_state().player.mana==12 and scene.interface_hud.hint.text=="The white globe holds a spell that does nothing here yet.","Actual inventory white refusal keeps both item and mana"):return
 scene.item_effects.put_on_belt(SCROLL,int(scene.item_effects.belt_state().active));await frames(12)
 await tap(KEY_F)
 if not require(SCROLL not in scene.carried_collected and scene.item_effects.state().spent.count(SCROLL)==1 and scene.starting_magic.magic_state().player.mana==9,"Actual F on belt scroll uses the original stored Spark3 dispatch once"):return
 if not await disk_cycle("belt_refusals"):return
 if not require(WHITE in scene.carried_collected and scene.item_effects.state().spent.count(SCROLL)==1,"F5/F9 keeps refusals and accepted scroll receipt"):return
 print("PASS real F inventory-pause/mana/cooldown refusals, exact empty sources, actual inventory globe cast/white refusal, belt scroll same dispatch/F5F9; resource/clock/grant component fixtures")
 quit()
