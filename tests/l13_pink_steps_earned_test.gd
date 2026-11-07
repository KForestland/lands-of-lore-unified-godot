extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 if not check(FileAccess.get_sha256("res://tmp/l13_dawn_recess_qualified_save.json")=="d6fa35d0d0cb99fc87303a651b33c4011c062df49fb1aaa29c006e900abf8e3d","qualified Dawn input"):quit(1);return
 var input=Save.read_save("res://tmp/l13_dawn_recess_qualified_save.json","lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Dawn input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_pink_steps_walk.json"))
 if not await walk(scene,route.points,"pink staircase approach"):quit(1);return
 
 for step in route.steps:
  var goal:=Vector3(step.point[0],0,step.point[1]+8);var arrived:=false;var peak:float=-9999
  for attempt in 5:
   scene.jump_requested=true
   for tick in 100:
    var d:Vector3=goal-scene.player.position;d.y=0
    scene.move_grounded(d.normalized() if d.length()>2 else Vector3.ZERO,1.0/60,true);await physics_frame
    peak=maxf(peak,scene.player.position.y)
    if scene.player.is_on_floor() and scene.player.position.y-32>=step.height-8:arrived=true;break
   if arrived:break
  print("STEP ",step.region," goal",goal," height",step.height," player",scene.player.position," arrived",arrived," peak",peak)
  if not check(arrived,"physical side-ledge jump"):quit(1);return
 if not await walk(scene,route.top,"upper bridge approach"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l13_pink_steps_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_pink_steps_earned_save.json").is_empty(),"earned top save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Dawn exit -> physical side ledge jumps beside original pink plates -> upper bridge approach -> actual save/reload")
 quit(0 if failures==0 else 1)
