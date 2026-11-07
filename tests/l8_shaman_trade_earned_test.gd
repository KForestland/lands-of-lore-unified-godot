extends "res://tests/l9_chapel_earned_test.gd"
const Trade=preload("res://scripts/lol2/l8_shaman_trade.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l8_initiation_earned_save.json","lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual completed initiation input"):quit(1);return
 prepare(scene)
 var tribe=scene.get_node("L8Tribe");var before:Array=scene.carried_collected.duplicate()
 check(not tribe.offer_shaman("wrong").ok,"remote shaman refused")
 scene.camera.look_at(scene.act2_creatures.bodies["23"].position+Vector3.UP*45,Vector3.UP)
 if not check(tribe.leave_arena(),"earned post-bout departure"):quit(1);return
 check(Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(531,-4414))<1,"original SETTLE1 world exit")
 check(scene.carried_collected==before and not tribe.leave_arena(),"departure neither changes inventory nor repeats")
 if not await walk(scene,[[600,-4400],[676,-4390]],"return shaman"):quit(1);return
 var leaf:String=scene.carried_collected.filter(func(id):return Trade.Items.definition(id)==117)[0]
 check(not tribe.offer_shaman("wrong").ok and scene.carried_collected==before,"wrong shaman offer preserves inventory")
 check(not Trade.exchange(Trade.initial(),[leaf,"other"],leaf,1).ok,"insufficient post-exchange capacity refuses atomically")
 check(Trade.exchange(Trade.initial(),[leaf],leaf,1).ok,"valid full inventory uses vacated leaf slot")
 var result:Dictionary=scene.get_node("L8Journey").interact("shaman_silverleaf",leaf)
 if not check(result.ok,str(result)):quit(1);return
 check(leaf not in scene.carried_collected and Trade.SERUM in scene.carried_collected and scene.carried_collected.size()==before.size(),"second leaf exchanged for original serum119")
 before=scene.carried_collected.duplicate()
 check(not tribe.offer_shaman(leaf).ok and before==scene.carried_collected,"duplicate shaman trade refused")
 var path:="res://tmp/l8_shaman_serum_earned_save.json"
 var error:String=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"serum save: "+error)
 if error.is_empty():check(scene._quickload_unrecorded(path).is_empty(),"serum reload")
 check(Trade.completed(scene.quest_state[Trade.KEY]) and scene.carried_collected==before,"saved serum does not replay gift")
 check(scene.act2_creatures.state.actors["113"].health==500,"village guard unharmed")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no fall recovery or seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual initiation -> earned settlement world exit -> physical shaman approach -> second leaf Kit/Amaranth119 -> save/reload; no duplicate gift")
 quit(0 if failures==0 else 1)
