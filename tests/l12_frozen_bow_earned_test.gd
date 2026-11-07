extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_crevasse_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="914c3c190cdb784a4eb1896f84ef06be019eaebaf3c4a56cc76ae7f605ce3731","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var bow=scene.get_node("L12FrozenBow")
 check(not bow.take().ok and not bow.spark(2),"unmelted/wrong-level refusal")
 scene.camera.look_at(bow.POINT,Vector3.UP);scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast() and bow.state().remaining>0,"actual Spark hits original ice model89"):quit(1);return
 var before:Dictionary=bow.state().duplicate(true)
 paused=true
 for i in 12:await process_frame
 check(bow.state()==before,"pause freezes sinking timer");paused=false
 for i in 220:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if bow.state().remaining<=0:break
 check(not bow.take().ok and bow.ice.visible and not bow.sprite.visible,"missed window loses pickup opportunity and refreezes for logged retry")
 scene.camera.look_at(bow.POINT,Vector3.UP)
 if not check(scene.starting_magic.cast() and bow.state().remaining>0,"actual second Spark retries timed pickup"):quit(1);return
 scene.camera.look_at(bow.sprite.global_position,Vector3.UP)
 var carried:Array=scene.carried_collected.duplicate()
 check(not bow.take(carried.size()).ok and scene.carried_collected==carried,"full inventory refusal without loss")
 var error:String=scene._quicksave_unrecorded("res://tmp/l12_bow_sinking_save.json")
 if not check(error.is_empty(),"sinking save: "+error):quit(1);return
 error=scene._quickload_unrecorded("res://tmp/l12_bow_sinking_save.json")
 if not check(error.is_empty(),"sinking reload: "+error):quit(1);return
 scene.camera.look_at(bow.sprite.global_position,Vector3.UP)
 if not check(bow.take().ok,"timely actual bow catch"):quit(1);return
 check(scene.carried_collected.count(bow.ITEM)==1 and not bow.take().ok and not bow.spark(1),"single pickup and no repeat reward")
 error=scene._quicksave_unrecorded("res://tmp/l12_frozen_bow_earned_save.json")
 if not check(error.is_empty(),"bow save: "+error):quit(1);return
 error=scene._quickload_unrecorded("res://tmp/l12_frozen_bow_earned_save.json")
 check(error.is_empty(),"bow reload: "+error)
 check(bow.state().taken and scene.carried_collected.count(bow.ITEM)==1 and scene.equipped_armor=="act2:L12_CM:item5" and scene.equipped_item=="act2:L13_RC:dark_sword","earned armor/sword/bow persist once")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Lizard grotto ->actual ice Spark ->missed window/retry ->timed bow catch/save-reload")
 quit(0 if failures==0 else 1)
