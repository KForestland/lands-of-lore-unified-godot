extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_pink_steps_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="cbc1aaee8444612f78eca25e00b4f87e1660238cdce73e9392f47366d56666a6","qualified pink ledges input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned upper landing input"):quit(1);return
 prepare(scene)
 var bridge=scene.get_node("L13Bridge")
 for i in 30:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 var before:Dictionary=bridge.state().duplicate(true);paused=true
 for i in 30:await process_frame
 check(bridge.state()==before,"paused bridge clock frozen");paused=false
 var vanished:=false
 for i in 600:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if not bridge.lit(90):vanished=true
  if vanished and float(bridge.state().phase)<0.05:break
 check(vanished and bridge.lit(90),"visible wave disappears and returns at safe landing")
 if not await walk(scene,[[-3207,-130]],"first visible plate"):quit(1);return
 for x in [-3340,-3480,-3600,-3720,-3850,-3930]:
  scene.jump_requested=true
  var landed:=false
  for tick in 120:
   var d:Vector3=Vector3(float(x),0,-130)-scene.player.position;d.y=0
   scene.move_grounded(d.normalized() if d.length()>2 else Vector3.ZERO,1.0/60,true);await physics_frame
   if tick>10 and scene.player.is_on_floor() and d.length()<5:landed=true;break
  print("BRIDGE jump ",x," at ",scene.player.position," phase",bridge.state().phase)
  if not check(landed and scene.player.position.y>35,"actual jump onto visible source plate"):quit(1);return
 check(scene.player.is_on_floor() and scene.player.position.y>35,"physical bridge reaches upper ring")
 check(scene._quicksave_unrecorded("res://tmp/l13_bridge_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_bridge_earned_save.json").is_empty(),"earned bridge save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned staircase landing -> timed visible source plates90..100 -> physical upper ring/save-reload")
 quit(0 if failures==0 else 1)
