extends "res://tests/generic_l13_chain_input_test.gd"
## Local real-key control loop; legacy F2 teaching is an explicit fixture.
func main():
 use_guard=false
 if not await start_from_f2():return
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("control"),"Disclosed learned Control Token fixture"):return
 await tap(KEY_3);magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(scene.player_form==2 and scene.curse.state.phase==0 and scene.curse.state.duration==0 and scene.curse.state.remaining==0 and magic.magic_state().player.mana==mana-2,"Real CtrlQ Curse3 applies persistent lizard at cost2, not the old 60s request"):return
 await picture("g15_curse3_lizard")
 if not await checkpoint("g15_curse3"):return
 await tap(KEY_F9);await adopt()
 magic=scene.starting_magic
 if not require(scene.player_form==2 and scene.curse.state.phase==0 and scene.curse.state.duration==0 and scene.player.get_child(0).shape is CylinderShape3D and scene.player.get_child(0).shape.height==8,"Actual F5/F9 retains persistent source lizard body"):return
 await ticks(40);magic.set_process(false);mana=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(scene.player_form==0 and scene.curse.state.phase==0 and magic.magic_state().player.mana==mana-2 and scene.resets==0,"Second real CtrlQ calls Curse2 and returns human at cost2"):return
 scene.curse.set_requests_enabled(true)
 if not require(scene.curse.request_timed_form(2,60.0) and scene.curse.state.phase==1,"Existing story curse can still start after chosen control"):return
 print("PASS G15 Curse3 real CtrlQ persistent source lizard/cost2/F5F9, next CtrlQ Curse2/cost2, future story warning admitted; teaching/clock/story fixtures disclosed")
 quit()
