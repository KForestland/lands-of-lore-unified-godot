extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_logs_approach_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="fb658dded3f142138e4706a83d84c42d2eaef2f043824545e8547f62b02871ff","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var glacier=scene.get_node("L12Glacier")
 check(glacier.state().started and glacier.logs.visible and glacier.state().motion.height==-1090,"earned Citadel return restores original six logs without changing lowered glacier floor")
 var logs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_return_logs.json"))
 var upper:=false
 for row in logs:
  if int(row.id) in [53,52]:continue # Step onto the original upper floor after log55.
  var target:=Vector3(row.point[0],row.point[1]+32,row.point[2])
  if not check(scene.request_jump(),"actual jump to original log"+str(row.id)):quit(1);return
  var airborne:=false;var landed:=false
  for tick in 240:
   var d:Vector3=target-scene.player.position;d.y=0
   scene.move_grounded(d.normalized() if d.length()>3 else Vector3.ZERO,1.0/60,true);await physics_frame
   if not scene.player.is_on_floor():airborne=true
   if airborne and scene.player.is_on_floor():landed=true;break
  print("LOG ",row.id," landed ",scene.player.position," target",target)
  if landed and scene.player.position.y> -562:upper=true;break
  if not check(landed and absf(scene.player.position.y-target.y)<3 and Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(target.x,target.z))<30 and scene.resets==0,"actual original log top"+str(row.id)):quit(1);return
 if not upper:
  check(scene.request_jump(),"actual jump from log55 onto original upper floor914")
  for tick in 240:
   var d:Vector3=Vector3(3500,0,-11570)-scene.player.position;d.y=0
   scene.move_grounded(d.normalized() if d.length()>3 else Vector3.ZERO,1.0/60,true);await physics_frame
   if tick>3 and scene.player.is_on_floor():break
 if not await walk(scene,[[3500,-11570]],"original upper return floor"):quit(1);return
 if not check(scene.player.position.y> -562 and scene.player.is_on_floor(),"original upper floor915 reached"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_return_logs_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_return_logs_earned_save.json").is_empty(),"earned log climb save/reload")
 check(scene.equipped_armor=="act2:L12_CM:item5" and "act2:L12_CM:blue_bow" in scene.carried_collected and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"earned items/no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned return ->ordinary jumps on original glacier logs ->upper floor/save-reload")
 quit(0 if failures==0 else 1)
