extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_niche_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="37590b39bacce043a5c5ce31be1a6cf6e9328b7dcdc2e1dc9d01325a453e6970","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_shard_bowls_approach.json"))
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Lizard return from niche"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual low corridor Lizard"):quit(1);return
 if not await walk(scene,route.low.slice(0,11),"return niche low corridor"):quit(1);return
 if not check(scene.request_jump(),"ordinary jump onto original floor-10 step"):quit(1);return
 if not await walk(scene,[[2912,-3685]],"first low return step"):quit(1);return
 if not check(scene.request_jump(),"ordinary jump onto original floor0 step"):quit(1);return
 if not await walk(scene,route.low.slice(13),"upper corridor to ritual"):quit(1);return
 if not check(passage.choose_form(),"Human in ritual room"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"actual Human ritual return"):quit(1);return
 if not await walk(scene,route.west,"opened hanging to original shard trays"):quit(1);return
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_shard_bowls_approach_earned_save.json")
 if not check(error.is_empty(),"tray approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_shard_bowls_approach_earned_save.json").is_empty(),"tray approach reload")
 check(scene.carried_collected.count("act2:L14_HT:item67")==1 and scene.carried_collected.count("act2:L14_HT:post_shard")==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same two shards no seeds/recovery")
 print("SHARD TRAYS APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned two shards -> physical niche return/hanging -> original shard tray406 approach/save-reload")
 quit(0 if failures==0 else 1)
