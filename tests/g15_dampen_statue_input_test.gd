extends "res://tests/helpers/g15_spell_input.gd"
func _initialize():main.call_deferred()
func main():
 if not await boot_legacy("res://tmp/g15_inputs/statue_midwalk.json","34ac34c948e5388292373cbd537f425dccbd59e4778b1bb68d121d3eeae40f58","lol2-restoration-dragon-preview","res://scenes/lol2/dragon_level.tscn"):return
 var walker:Node=scene.get_node("L9StatueWalk")
 if not require(not walker.state().arrived and not walker.state().fight_done and scene.player_form==0,"Genuine midwalk still requires human statue arrival"):return
 var magic=scene.starting_magic
 # Old packets deliberately start unlearned. Teaching is a disclosed component
 # fixture here; the actual Dawn sequence is covered by monastery_dawn_dampen.
 if not require(magic.learn_spell_group("dampen"),"Explicit legacy-checkpoint learning fixture"):return
 scene.curse.set_requests_enabled(true)
 if not require(scene.curse.request_timed_form(2,60.0),"Disclosed natural warning request, no form write"):return
 magic.set_process(false);var mana:int=magic.magic_state().player.mana
 await tap(KEY_3);await tap(KEY_Q)
 if not require(scene.curse.state.phase==0 and scene.player_form==0 and magic.magic_state().player.mana==mana-1,"Actual Q preserves human through Dampen"):return
 magic.set_process(true)
 var points:Array=[]
 for i in range(6,12):
  var p:Array=walker.source.path.points[i].position
  points.append(p.duplicate())
 if not await walk(points,"Real W follows original statue path after Dampen",{"final_reach":6.0}):quit(1);return
 if not walker.movie_active:
  if not await walk([[4111,-9959],[4200,-10100]],"Real W into original statue fight trigger"):quit(1);return
 for tick in 9000:
  if walker.movie_active:break
  await physics_frame
 if not require(walker.movie_active and paused and scene.player_form==0 and scene.resets==0,"Actual human arrival starts original fight movie after Dampen"):return
 await picture("dampen_statue_fight")
 print("PASS G15 Dampen actual Q/cost1 then real W original statue path: movie54 begins as human, resets0; pinned aided legacy midwalk/learning/story request disclosed")
 quit()
