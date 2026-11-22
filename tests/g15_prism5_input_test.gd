extends "res://tests/helpers/g15_world_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L20_BB"):return
 var pillars:Node=scene.get_node("L20PillarsScotia")
 if not await stand_at(pillars.SCOTIA_AT+Vector3(0,32,0)):return
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("prism"),"Disclosed Prism learning fixture"):return
 await tap(KEY_5);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_E)
 if not require(not pillars.state().trinity,"Real E no longer performs Trinity"):return
 await tap(KEY_Q);await tap(KEY_Q,true)
 if not require(not pillars.state().trinity and magic.magic_state().player.mana==mana,"Prism1/3 refuse without debit or effect"):return
 await tap(KEY_Q,false,true);await frames(3)
 if not require(pillars.state().trinity and pillars.state().pillars_moved and not pillars.state().path_open and magic.magic_state().player.mana==mana-5,"Real ShiftQ Trinity cost5 starts carrier; unsolved pillar row stays separate"):return
 if not require(not pillars.scotia_body.visible and pillars.carrier.visible,"Faux Scotia falls, existing carrier drawn"):return
 await picture("g15_prism5_trinity")
 magic.set_process(true);await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,false,true)
 if not require(magic.magic_state().player.mana==mana,"Duplicate Trinity refuses without debit"):return
 if not await disk_cycle("g15_prism5"):return
 if not require(scene.get_node("L20PillarsScotia").state().trinity and scene.get_node("L20PillarsScotia").state().pillars_moved and not scene.get_node("L20PillarsScotia").state().path_open,"Real F5/F9 preserves independent Trinity and shot states"):return
 print("PASS G15 Prism5 actual E negative/ShiftQ cost5/carrier/path separation/wrongcharges/duplicate/F5F9; explicit stand/teaching/clock fixtures, no earned walk claim")
 quit()
