extends "res://tests/generic_l13_chain_input_test.gd"
## Local cast proof: genuine F2 start; disclosed learning and production timed-
## curse requests arrange the warning. Actual keys cast; no pose/resource writes.
func main():
 use_guard=false
 if not await start_from_f2():return
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("dampen"),"Disclosed learned Dampen fixture; actual grant qualified separately"):return
 scene.curse.set_requests_enabled(true)
 if not require(scene.curse.request_timed_form(2,60.0),"Disclosed production story-warning request"):return
 var mana:int=magic.magic_state().player.mana
 magic.set_process(false)
 await tap(KEY_3);await tap(KEY_Q)
 if not require(scene.curse.state.phase==0 and scene.player_form==0 and magic.magic_state().player.mana==mana-1,"Real Q Dampen cancels warning at cost1 and keeps human"):return
 await ticks(240)
 if not require(scene.curse.state.phase==0 and scene.player_form==0 and scene.resets==0,"Beyond original warning, still human without recovery"):return
 await picture("g15_dampen_keeps_human")
 magic.set_process(true);await ticks(40);magic.set_process(false)
 var before:Dictionary=magic.magic_state().duplicate(true)
 await tap(KEY_Q)
 if not require(magic.magic_state()==before and scene.curse.state.phase==0,"Dampen at phase0 refuses without debit"):return
 if not await checkpoint("g15_dampen"):return
 await tap(KEY_F9);await adopt()
 magic=scene.starting_magic
 if not require("curse1" in magic.magic_state().spellbook.learned and scene.curse.state.phase==0 and scene.player_form==0,"Real F5/F9 retains learned Dampen and canceled warning"):return
 scene.curse.set_requests_enabled(true)
 if not require(scene.curse.request_timed_form(2,60.0),"Second disclosed warning for phase2 negative"):return
 await ticks(240)
 if not require(scene.player_form==2 and scene.curse.state.phase==2,"Uncancelled story warning still morphs naturally"):return
 magic.set_process(false);before=magic.magic_state().duplicate(true)
 await tap(KEY_3);before=magic.magic_state().duplicate(true);await tap(KEY_Q)
 if not require(scene.curse.state.phase==2 and scene.player_form==2 and magic.magic_state()==before,"Phase2 Dampen does not undo a landed morph or debit mana"):return
 print("PASS G15 Curse1 actual keys cancel warning/cost1/save-reload; phase0/2 negatives, normal uncancelled morph. Learning/story-request/held-magic-clock fixtures disclosed; no statue-chain claim")
 quit()
