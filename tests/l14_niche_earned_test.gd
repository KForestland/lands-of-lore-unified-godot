extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_niche_approach_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="6957d142a59771c30056b247bbfd78089e15f9390bcf7eca5e0fd9fb845fccb4","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var niche=scene.get_node("L14Niche")
 var items=scene.get_node("Act2WorldItems")
 var pedestal_ray=PhysicsRayQueryParameters3D.create(Vector3(2691,50,-3887),Vector3(2691,-90,-3887),1)
 var closed_grate:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(pedestal_ray)
 check(not closed_grate.is_empty() and absf(closed_grate.position.y+20)<0.1,"original closed grate collision above pedestal")
 check(not items.available(niche.SHARD),"original shard not released before statue")
 scene.camera.look_at(niche.POINT,Vector3.UP)
 check(not niche.offer("act2:L14_HT:item77").ok,"wrong flute refused by Kit")
 check(not niche.offer(niche.STATUE,scene.carried_collected.size()).ok,"full output capacity refused without statue loss")
 paused=true;check(not niche.offer().ok,"paused offering refused");paused=false
 if not check(niche.offer().ok,"Kit original machine statue into original126"):quit(1);return
 check(not niche.offer().ok,"repeat statue insertion refused")
 check(niche.STATUE not in scene.carried_collected,"one statue consumed into niche")
 await physics_frame
 var before:float=niche.state().raised
 paused=true
 for i in 10:await process_frame
 check(niche.state().raised==before,"paused pedestal clock frozen")
 paused=false
 for i in 160:await physics_frame
 check(niche.state().raised==2,"original pedestal floors risen70")
 var raised_floor:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(pedestal_ray)
 check(not raised_floor.is_empty() and absf(raised_floor.position.y)<0.1,"actual original pedestal floor rises70 to0")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_niche_inserted_save.json")
 if not check(error.is_empty(),"inserted statue save: "+error):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_niche_inserted_save.json").is_empty(),"inserted statue reload"):quit(1);return
 if not await walk(scene,[[2760,-3900],[2730,-3888]],"original raised shard pedestal"):quit(1);return
 scene.camera.look_at(items.aim_point(niche.SHARD),Vector3.UP)
 if not check(items.take(niche.SHARD),"take same original shard67 from raised pedestal"):quit(1);return
 check(not items.take(niche.SHARD),"second shard not duplicated")
 error=scene._quicksave_unrecorded("res://tmp/l14_niche_earned_save.json")
 if not check(error.is_empty(),"two shard save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_niche_earned_save.json").is_empty(),"two shard reload")
 check(scene.carried_collected.count(niche.SHARD)==1 and scene.carried_collected.count("act2:L14_HT:post_shard")==1 and niche.STATUE not in scene.carried_collected,"two distinct earned shards, statue stays placed")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 print("TWO SHARDS ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned machine statue -> Kit niche126 -> original pedestal/grates/shard67 -> two shards/save-reload")
 quit(0 if failures==0 else 1)
