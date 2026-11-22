extends "res://tests/helpers/g15_world_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_map("L20_BB"):return
 var mother:Node=scene.get_node("L20MotherCurse")
 # Exact valid Dawn-talk prerequisite fixture, not earned in this component.
 var prerequisite:Dictionary=mother.initial();prerequisite.clicks=2;prerequisite.curse_said=true;prerequisite.line=mother.CURSE_LINE
 if not require(mother.validate(prerequisite).is_empty(),"Schema-valid Dawn speech fixture"):return
 if not await stand_at(Vector3(mother.MOTHER_AT.x,mother.MOTHER_AT.y+32,mother.MOTHER_AT.z)):return
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("control"),"Disclosed learned Control Token fixture"):return
 await tap(KEY_3);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q,false,true)
 if not require(not mother.state().glob_entered and magic.magic_state().player.mana==mana and scene.interface_hud.hint.text=="The mother shoots a fireball back. She does not die.","Before Dawn's words Expel refuses with the existing plain line and no debit"):return
 scene.quest_state[mother.KEY]=prerequisite
 await tap(KEY_E);await frames(3)
 if not require(not mother.state().glob_entered,"Real E at mother no longer performs Expel"):return
 await tap(KEY_Q)
 if not require(not mother.state().glob_entered and magic.magic_state().player.mana==mana,"Curse1 cannot enter the mother"):return
 await tap(KEY_Q,true)
 if not require(not mother.state().glob_entered and scene.player_form==2,"Curse3 changes form but cannot perform Expel"):return
 magic.set_process(true);await ticks(40);magic.set_process(false)
 await tap(KEY_Q,true)
 if not require(not mother.state().glob_entered and scene.player_form==0,"Curse2 also leaves the mother unchanged"):return
 magic.set_process(true);await ticks(40);magic.set_process(false)
 mana=magic.magic_state().player.mana
 await tap(KEY_Q,false,true);await frames(3)
 if not require(mother.state().glob_entered and magic.magic_state().player.mana==mana-5 and not mother.state().demons_killed,"Real ShiftQ Expel runs birth once at fixed cost5"):return
 if not require(scene.interface_hud.hint.text=="The curse enters the mother.","Successful Expel replaces its earlier refusal with plain success feedback"):return
 await picture("g15_expel_birth")
 if is_instance_valid(mother.overlay):await tap(KEY_ESCAPE)
 await ticks(60)
 if not require(hp()>0 and scene.resets==0,"Native birth relocation leaves Luther alive without recovery"):return
 magic.set_process(true);await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,false,true)
 if not require(magic.magic_state().player.mana==mana and mother.state().glob_entered,"Second Expel refuses without debit"):return
 await tap(KEY_E);await ticks(150)
 if not require(mother.state().demons_killed and mother.state().mother_dead and mother.state().creatures_cleared,"Separate real E demons-fall beat remains after birth"):return
 if not await disk_cycle("g15_expel"):return
 if not require(scene.get_node("L20MotherCurse").state().glob_entered and scene.get_node("L20MotherCurse").state().demons_killed,"Actual F5/F9 keeps Expel and separate demons beat"):return
 print("PASS G15 Expel actual E negative/ShiftQ cost5/native birth/E demons/F5F9; explicit stand, valid Dawn and teaching/clock fixtures, no earned-chain claim")
 quit()
