extends "res://tests/helpers/g15_world_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L16_CA"):return
 var traps:Node=scene.get_node("L16NwTraps")
 if not await stand_at(Vector3(-8940,132,-3286)):return
 if not await look(traps.ICE_AT):quit(1);return
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("summon"),"Disclosed Summon learning fixture"):return
 await tap(KEY_1);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(not traps.state().ice and magic.magic_state().player.mana==mana-3,"Real Spark3 retains bolt/cost but no longer breaks white ball"):return
 magic.set_process(true);await ticks(40);magic.set_process(false)
 await tap(KEY_6);mana=magic.magic_state().player.mana
 await tap(KEY_Q)
 if not require(not traps.state().ice and magic.magic_state().player.mana==mana,"Summon1 refuses with no debit"):return
 await tap(KEY_Q,true)
 if not require(traps.state().ice and magic.magic_state().player.mana==mana-3 and traps.bodies[90].collision_layer==0,"Real Summon CtrlQ breaks same white-ball body for3mana"):return
 await picture("g15_summon_city")
 if not await disk_cycle("g15_summon_city"):return
 if not require(scene.get_node("L16NwTraps").state().ice and scene.get_node("L16NwTraps").bodies[90].collision_layer==0,"Real F5/F9 preserves broken ice body"):return
 print("PASS G15 Summon3 City real Spark3 negative/SummonCtrlQcost3/same body/F5F9, stand/learning/clock fixtures; no earned walk claim")
 quit()
