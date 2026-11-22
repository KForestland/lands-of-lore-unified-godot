extends "res://tests/helpers/g15_world_spell_input.gd"
## Fresh modern books at named requirements. Supplied grounded local stands;
## actual keys/aim and existing prerequisites. Not an earned route.
func _initialize():main.call_deferred()
func fresh(area_name:String)->bool:
 if is_instance_valid(scene):scene.queue_free();await process_frame
 return await boot_map(area_name)
func learned(id:String)->bool:return id in scene.starting_magic.magic_state().spellbook.learned
func main():
 if not await fresh("L12_CM"):return
 if not require(not learned("curse3"),"Unlearned Control before the crevasse"):return
 var crevasse:Node=scene.get_node("L12Crevasse")
 if not await stand_at(crevasse.SPARK+Vector3(160,0,0)):return
 if not require(learned("curse2") and learned("curse3") and learned("curse5"),"Actual crevasse approach teaches the normal Control group"):return
 var magic:Node=scene.starting_magic
 await tap(KEY_3);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(scene.player_form==2 and magic.magic_state().player.mana==mana-2,"Real CtrlQ chooses persistent Lizard after local teaching"):return
 magic.set_process(true);await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(scene.player_form==0 and magic.magic_state().player.mana==mana-2,"Real CtrlQ returns Human with the paired lesson"):return
 if not await fresh("L16_CA"):return
 if not require(not learned("mists3") and not learned("summon3"),"Fresh City book does not gain spells by chapter"):return
 if not await stand_at(Vector3(-4111,107,15386)):return
 if not await look(Vector3(-4111,145,15457)):quit(1);return
 if not require(learned("mists3") and not scene.get_node("L16FountainFreeze").state().frozen,"Fountain admission teaches without freezing"):return
 magic=scene.starting_magic;await tap(KEY_4);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(scene.get_node("L16FountainFreeze").state().frozen and magic.magic_state().player.mana==mana-3,"Actual CtrlQ freezes only after teaching, at cost3"):return
 magic.set_process(true);await ticks(40)
 var traps:Node=scene.get_node("L16NwTraps")
 if not await stand_at(Vector3(-8940,132,-3286)):return
 if not await look(traps.ICE_AT):quit(1);return
 if not require(learned("summon3") and not traps.state().ice,"White ball admission teaches without breaking it"):return
 await tap(KEY_6);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(traps.state().ice and magic.magic_state().player.mana==mana-3,"Actual Summon3 breaks the admitted ball for cost3"):return
 if not await fresh("L20_BB"):return
 if not require(not learned("prism5") and not learned("curse5"),"Fresh L20 book is not filled by an area load"):return
 var mother:Node=scene.get_node("L20MotherCurse")
 if not await stand_at(mother.MOTHER_AT+Vector3.UP*32):return
 if not require(learned("curse5") and not mother.state().curse_said and not mother.state().glob_entered,"Mother approach teaches Expel, preserves talk and birth prerequisites"):return
 magic=scene.starting_magic;await tap(KEY_3);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,false,true)
 if not require(not mother.state().glob_entered and magic.magic_state().player.mana==mana,"Actual Expel still refuses before required instructions"):return
 magic.set_process(true)
 var pillars:Node=scene.get_node("L20PillarsScotia")
 if not await stand_at(pillars.SCOTIA_AT+Vector3.UP*32):return
 if not require(learned("prism5") and not pillars.state().trinity,"Scotia approach teaches Trinity without its outcome"):return
 await tap(KEY_5);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,false,true)
 if not require(pillars.state().trinity and magic.magic_state().player.mana==mana-5,"Actual ShiftQ performs learned Trinity for cost5"):return
 if not require(scene.resets==0 and Engine.time_scale==1,"Ordinary clock, no recovery"):return
 print("PASS fresh-book local Control2/3, City Mists3/Summon3, L20 Expel lesson with guard refusal and Trinity5; actual keys/costs/no auto-outcomes; component stands, not earned route")
 quit()
