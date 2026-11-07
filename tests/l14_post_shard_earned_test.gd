extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_priest_ritual_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="44b09c398e7eeb301db5f5b3875d51d77f925b138282c3c24d5a0294c431f6ec","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var shard=scene.get_node("L14PostShard")
 check(not shard.take().ok,"remote post pickup refused")
 var points:Array=[[2500,-3328],[2600,-3400],[2800,-3450],[3000,-3500],[3100,-3750],[3000,-3900],[3000,-4050],[3000,-4300],[3043,-4550],[3043,-4750],[3043,-4950],[3043,-5150],[3043,-5400],[3043,-5600]]
 if not await walk(scene,points,"north of pews to source post71"):quit(1);return
 scene.camera.look_at(shard.POINT,Vector3.UP)
 var before:Array=scene.carried_collected.duplicate()
 check(not shard.take(before.size()).ok and scene.carried_collected==before,"full inventory refuses without loss")
 paused=true;check(not shard.take().ok,"paused pickup refused");paused=false
 if not check(shard.take().ok,"actual source post71 shard pickup"):quit(1);return
 check(not shard.take().ok,"post cannot grant twice")
 check(scene._quicksave_unrecorded("res://tmp/l14_post_shard_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l14_post_shard_earned_save.json").is_empty(),"earned post shard save/reload")
 check(scene.carried_collected.count(shard.ITEM)==1 and shard.state().taken and not shard.sprite.visible,"single original-identity shard persists")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned priest ritual -> physical pew/north room -> original control71 shard identity pickup/save-reload")
 quit(0 if failures==0 else 1)
