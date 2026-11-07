extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l8_temple_shard_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="88fd2b133b1d7bdbf91d8692367e2fd6491cb141f8b17a023ee6603bd0cdfe00","qualified river return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned jungle input"):quit(1);return
 prepare(scene)
 var tree=scene.get_node("L8Tree")
 check(not tree.interact("insert","act2:L14_HT:post_shard").ok,"remote tree slot refuses")
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_tree_approach.json"))
 if not await walk(scene,points,"raised-platform tree approach"):quit(1);return
 points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_tree_steps.json"))
 if not await walk(scene,points,"original lower stairs to platform"):quit(1);return
 if not await walk(scene,[[-1000,-2370]],"torch platform"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l8_tree_platform_earned_save.json").is_empty(),"earned platform save")
 for id in tree.TORCHES:
  scene.camera.look_at(tree.TORCHES[id],Vector3.UP)
  for i in 180:
   await physics_frame
   if scene.starting_magic.magic_state().cooldown<=0:break
  scene.starting_magic.select_spell("spark")
  if not check(scene.starting_magic.cast(),"actual Spark torch"+id):quit(1);return
  await physics_frame
  if not check(id in tree.state().lit,"original torch lit "+id):quit(1);return
  check(not tree.spark(id,1),"same torch cannot count twice")
 var rise:float=tree.state().rise;paused=true
 for i in 10:await process_frame
 check(tree.state().rise==rise,"paused stair motion");paused=false
 for i in 180:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if tree.state().rise>=2:break
 check(tree.state().rise==2,"all source stair targets reached")
 var error:String=scene._quicksave_unrecorded("res://tmp/l8_tree_raised_earned_save.json")
 check(error.is_empty(),"raised stairs save: "+error)
 error=scene._quickload_unrecorded("res://tmp/l8_tree_raised_earned_save.json")
 check(error.is_empty(),"raised stairs reload: "+error)
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Temple shard jungle return -> physical tree/platform -> five actual Sparks -> original stair rise/save-reload")
 quit(0 if failures==0 else 1)
