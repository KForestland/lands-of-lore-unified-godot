extends "res://tests/l9_chapel_earned_test.gd"
const Dawn=preload("res://scripts/lol2/l8_dawn_state.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/act2_silverleaf_qualified/l8_shore_earned_save.json","lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"qualified earned shore input"):quit(1);return
 prepare(scene)
 var dawn=scene.get_node("L8Dawn")
 check(Dawn.BRACERS in scene.carried_collected,"actual recovered L9 bracers carried")
 scene.camera.look_at(dawn.AIM,Vector3.UP)
 var before:Array=scene.carried_collected.duplicate()
 check(not dawn.interact("wrong").ok and scene.carried_collected==before,"wrong item refused without mutation")
 paused=true
 check(not dawn.interact().ok,"paused exchange refused")
 paused=false
 scene.player_form=1
 check(not dawn.interact().ok,"nonhuman exchange refused")
 scene.player_form=0
 check(dawn.reachable(),"original Dawn20 physically reachable from shore")
 var result:Dictionary=dawn.interact()
 if not check(result.ok,str(result)):quit(1);return
 check(Dawn.TOKEN in scene.carried_collected and Dawn.BRACERS not in scene.carried_collected,"one source token for actual bracers")
 check(scene.carried_collected.size()==before.size(),"exchange conserves inventory count")
 before=scene.carried_collected.duplicate()
 check(not dawn.interact().ok and scene.carried_collected==before,"duplicate exchange refused")
 var path:="res://tmp/l8_dawn_earned_save.json"
 var error:String=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"save earned Dawn exchange: "+error)
 if error.is_empty():check(scene._quickload_unrecorded(path).is_empty(),"reload earned Dawn exchange")
 check(Dawn.completed(dawn.state()) and scene.carried_collected==before,"reload does not replay reward")
 check(scene.progression.seeds_applied.is_empty(),"no arrival seeds")
 # Capacity checks use pure snapshots only; never inject inventory into campaign.
 var full:Array=[Dawn.BRACERS,"other"]
 var refused:=Dawn.exchange(Dawn.initial(),full,Dawn.BRACERS,1)
 check(not refused.ok and full==[Dawn.BRACERS,"other"],"capacity refusal atomic")
 check(Dawn.exchange(Dawn.initial(),[Dawn.BRACERS],Dawn.BRACERS,1).ok,"full valid inventory exchanges in vacated slot")
 scene.queue_free();await process_frame
 if failures==0:print("PASS qualified earned shore -> Dawn20 Kit bracer exchange -> original ControlToken -> save/reload; wrong item/form/pause/duplicate/capacity guards")
 quit(0 if failures==0 else 1)
