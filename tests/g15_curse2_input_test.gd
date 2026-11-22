extends "res://tests/generic_l13_chain_input_test.gd"
## Component continuation: genuine F2, explicit control learning and timed
## warning fixtures. Keys perform the cast; no pose/health/mana writes.
func main():
 use_guard=false
 if not await start_from_f2():return
 var magic=scene.starting_magic
 if not require(magic.learn_spell_group("control"),"Disclosed learned Control Token fixture"):return
 scene.curse.set_requests_enabled(true)
 if not require(scene.curse.request_timed_form(2,60.0),"Disclosed normal story warning"):return
 await tap(KEY_3)
 magic.set_process(false);var initial:Dictionary=magic.magic_state().duplicate(true)
 await tap(KEY_Q,true)
 if not require(scene.curse.state.phase==1 and scene.player_form==0 and magic.magic_state()==initial,"CtrlQ during phase1 refuses with no debit"):return
 await ticks(240)
 if not require(scene.player_form==2 and scene.curse.state.phase==2,"Normal warning produces a live lizard"):return
 var mana:int=magic.magic_state().player.mana
 await tap(KEY_Q,true)
 if not require(scene.player_form==0 and scene.curse.state.phase==0 and scene.curse.state.remaining==0 and scene.curse.state.duration==0 and magic.magic_state().player.mana==mana-2,"Real CtrlQ Curse2 returns lizard to human at cost2 with no timer"):return
 if not require(not scene.curse.accepts_player_spell("curse2"),"Human cannot receive the lizard-to-human cast"):return
 await picture("g15_curse2_human")
 if not await checkpoint("g15_curse2"):return
 await tap(KEY_F9);await adopt()
 if not require(scene.player_form==0 and scene.curse.state.phase==0 and scene.curse.state.duration==0 and "curse2" in scene.starting_magic.magic_state().spellbook.learned and scene.resets==0,"Actual F5/F9 keeps controlled human, book and no recovery"):return
 print("PASS G15 Curse2 real CtrlQ from natural lizard, fixed cost2, no form timer, phase1 refusal and F5/F9. Learning/story-request/held-magic-clock fixtures disclosed")
 quit()
