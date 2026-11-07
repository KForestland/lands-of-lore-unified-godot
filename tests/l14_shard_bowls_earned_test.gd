extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_shard_bowls_approach_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="172747e16f69e735da0a97cd8ff5435a158b5888cb389dbacb4843a1b819f6b6","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var bowls=scene.get_node("L14ShardBowls")
 var ray=PhysicsRayQueryParameters3D.create(Vector3(1100,65,-3453),Vector3(940,65,-3453),1)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"original passage closed before two shards")
 scene.camera.look_at(bowls.BOWLS["406"],Vector3.UP)
 check(not bowls.offer("406","act2:L14_HT:item77").ok,"wrong flute refused by Kit")
 paused=true;check(not bowls.offer("406",bowls.SHARDS[1]).ok,"paused shard insertion refused");paused=false
 if not check(bowls.offer("406",bowls.SHARDS[1]).ok,"first original suspended bowl accepts original67"):quit(1);return
 check(not bowls.offer("406",bowls.SHARDS[0]).ok,"occupied bowl refuses other earned shard")
 for i in 150:await physics_frame
 check(bowls.state().opened==0,"one shard does not open passage")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_one_bowl_save.json")
 if not check(error.is_empty(),"one bowl save: "+error):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_one_bowl_save.json").is_empty(),"one bowl reload"):quit(1);return
 if not await walk(scene,[[1235,-3455],[1235,-3310]],"other original suspended bowl405"):quit(1);return
 scene.camera.look_at(bowls.BOWLS["405"],Vector3.UP)
 check(not bowls.offer("405",bowls.SHARDS[1]).ok,"same consumed shard cannot fill two bowls")
 if not check(bowls.offer("405",bowls.SHARDS[0]).ok,"second original bowl accepts earned first shard"):quit(1);return
 await physics_frame
 var before:float=bowls.state().opened
 paused=true
 for i in 10:await process_frame
 check(bowls.state().opened==before,"paused passage clock frozen")
 paused=false
 for i in 160:await physics_frame
 check(bowls.state().opened==2,"two committed bowls open passage")
 check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"original passage collision opens")
 for x in [1040,1015,990]:
  var floor_ray=PhysicsRayQueryParameters3D.create(Vector3(x,110,-3453),Vector3(x,-200,-3453),1)
  var floor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(floor_ray)
  check(not floor_hit.is_empty() and absf(floor_hit.position.y-30)<0.1,"actual opened rear passage floor30")
 if not await walk(scene,[[1235,-3453],[1160,-3453],[1125,-3453],[1075,-3453],[1015,-3453],[940,-3453]],"actual passage behind suspended bowls"):quit(1);return
 error=scene._quicksave_unrecorded("res://tmp/l14_shard_bowls_earned_save.json")
 if not check(error.is_empty(),"passage save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_shard_bowls_earned_save.json").is_empty(),"passage reload")
 check(bowls.SHARDS[0] not in scene.carried_collected and bowls.SHARDS[1] not in scene.carried_collected,"both original earned shards remain in distinct bowls")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 print("BOWL PASSAGE ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned distinct shards -> Kit original405/406 -> original rear passage physical crossing/save-reload")
 quit(0 if failures==0 else 1)
