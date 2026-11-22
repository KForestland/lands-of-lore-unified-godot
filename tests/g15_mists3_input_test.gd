extends "res://tests/helpers/g15_world_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L16_CA"):return
 if not await stand_at(Vector3(-4111,107,15386)):return
 if not await look(Vector3(-4111,145,15457)):quit(1);return
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("mists"),"Disclosed Mists learning fixture"):return
 await tap(KEY_4);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q)
 if not require(not scene.quest_state.get("l16_fountain_freeze",{}).get("frozen",false) and magic.magic_state().player.mana==mana,"Mists1 does not freeze or debit at source fountain626"):return
 await picture("g15_fountain_before")
 await tap(KEY_Q,true)
 if not require(scene.quest_state.get("l16_fountain_freeze",{}).get("frozen",false) and magic.magic_state().player.mana==mana-3,"Real CtrlQ Mists3 freezes named fountain626 at fixed cost3"):return
 var fountain:Node=scene.get_node("L16FountainFreeze")
 if not require(fountain.frozen_mesh.is_visible_in_tree() and fountain.source.record==626 and fountain.source.region==4900,"Visible frozen source artwork at decoded fountain, not dry/SW adapter"):return
 await frames(3);await picture("g15_fountain_frozen")
 magic.set_process(true);await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(magic.magic_state().player.mana==mana,"Already frozen fountain refuses without debit"):return
 if not await disk_cycle("g15_fountain_freeze"):return
 if not require(scene.get_node("L16FountainFreeze").state().frozen and scene.get_node("L16FountainFreeze").frozen_mesh.is_visible_in_tree(),"Real F5/F9 keeps freeze and source art"):return
 print("PASS G15 Mists3 actual CtrlQ source626/frozen visual/cost3, Mists1 negative/repeat/F5F9, explicit stand/teaching/clock fixtures; chip step remains unhosted")
 quit()
