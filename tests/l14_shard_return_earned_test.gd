extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_post_shard_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="4d984c348999d3413d5495cc689f9c93f305b4b72f0173bf9864becbba099b4c","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var points:Array=[[3043,-5400],[3043,-5150],[3043,-4950],[3043,-4750],[3043,-4550],[3000,-4300],[3000,-4050],[3000,-3900],[3100,-3750],[3000,-3500],[2800,-3450],[2600,-3400],[2500,-3328],[2413,-3328]]
 if not await walk(scene,points,"return shard through Temple"):quit(1);return
 points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_entry_walk.json"));points.reverse();points.append([2411,-2413]);points.append([2411,-2300])
 if not await walk(scene,points,"original Temple exit863"):quit(1);return
 for i in 5:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"native Temple exit entered"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 if not check(change.level==8 and change.selector==3,"native L8 selector3"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene._quicksave_unrecorded("res://tmp/l8_temple_shard_return_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l8_temple_shard_return_earned_save.json").is_empty(),"earned jungle shard arrival save/reload")
 check(scene.carried_collected.count("act2:L14_HT:post_shard")==1 and scene.carried_collected.count("act2:L13_RC:dreamstone")==1,"earned crystals retained")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned post shard -> physical Temple return -> native L8selector3 -> retained crystals/save-reload")
 quit(0 if failures==0 else 1)
