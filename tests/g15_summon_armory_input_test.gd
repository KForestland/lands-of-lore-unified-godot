extends "res://tests/helpers/g15_world_spell_input.gd"
const Grants=preload("res://scripts/lol2/item_grants.gd")
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L20_BB"):return
 var arm:Node=scene.get_node("L20Armory")
 var magic=scene.starting_magic
 # Inventory/equipment fixture admits the already-existing sword and bow.
 for id:String in ["act2:L13_RC:dark_sword",arm.BLUE_BOW]:
  if not require(Grants.grant(scene,id,{"cap":false,"history":"act2_once","sync":true}).ok,"Disclosed valid equipment grant fixture"):return
 scene.equipped_item="act2:L13_RC:dark_sword"
 if not require(magic.learn_spell_group("summon"),"Disclosed Summon learning fixture"):return
 await tap(KEY_6);magic.set_process(false)
 if not await stand_at(Vector3(-2650,-18,-2854)):return
 if not await look(arm.AT_196):quit(1);return
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(not arm.state().ball and magic.magic_state().player.mana==mana,"Summon before brick prerequisite refuses without debit"):return
 if not await stand_at(arm.AT_62+Vector3(0,32,0)):return
 await tap(KEY_E)
 if not require(arm.state().hacked and not arm.state().ball and not arm.state().fire and not arm.state().stopped,"Real E hacks only the brick, never ball/fire/stopped"):return
 if not await stand_at(Vector3(-2650,-18,-2854)):return
 if not await look(arm.AT_196):quit(1);return
 mana=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(arm.state().ball and not arm.state().fire and not arm.state().stopped and magic.magic_state().player.mana==mana-3,"Real Summon3 costs3; bow requirement remains separate"):return
 if not await stand_at(Vector3(-3619,-18,-3361)):return
 if not await look(arm.AT_197):quit(1);return
 scene.hand_item="act2:L13_RC:dark_sword"
 await lclick()
 if not require(not arm.state().fire and not arm.state().stopped,"Wrong hand does not break fireball"):return
 scene.hand_item=arm.BLUE_BOW
 await lclick();await frames(3)
 if not require(arm.state().fire and arm.state().stopped and arm.BLUE_BOW in scene.carried_collected,"Real blue-bow click finishes three separate requirements without consuming bow"):return
 await picture("g15_summon_armory")
 if not await disk_cycle("g15_summon_armory"):return
 if not require(scene.get_node("L20Armory").state().stopped and scene.get_node("L20Armory").BLUE_BOW in scene.carried_collected,"Real F5/F9 preserves all three breaks and carried bow"):return
 print("PASS G15 Summon3 armory real E brick-only/CtrlQball/bluebow click/all3 stop/F5F9; explicit stand/grants/equipment/learning/clock fixtures, no earned walk claim")
 quit()
