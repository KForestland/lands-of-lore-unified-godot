extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_niche_armor_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="82a30064ec56387c518c7a1d21b791e2e84ba43aafde7353df9ed64f2b75d4aa","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var rafts=scene.get_node("L12RiverRafts")
 if not await walk(scene,[[100,-14165]],"niche shore"):quit(1);return
 var boat:=-1
 for tick in 18000:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  for i in 3:
   var c:Vector3=rafts.centre(i)
   if c.x<500 and c.z< -14065 and c.z> -14085:boat=i;break
  if boat>=0:break
 if not check(boat>=0,"next actual river raft reaches niche"):quit(1);return
 check(scene.request_jump(),"actual sprint-jump back onto raft")
 var landed:=false
 for tick in 240:
  var d:Vector3=rafts.centre(boat)-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>8 else Vector3.ZERO,1.0/60,true);await physics_frame
  if tick%30==0:print("BOARD ",tick," ",scene.player.position," raft",rafts.centre(boat)," riding",rafts.riding())
  if rafts.riding()==boat:landed=true;break
  if tick>3 and scene.player.is_on_floor():break
 if not check(landed,"first landing is the moving raft"):quit(1);return
 var near:=false
 for tick in 18000:
  var c:Vector3=rafts.centre(boat)
  var target:Vector3=c+Vector3(64,32,145) if c.x>2900 and c.x<3350 and c.z> -12800 and c.z< -12200 else c+Vector3.UP*32
  var d:Vector3=target-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>5 else Vector3.ZERO,1.0/60);await physics_frame
  if tick%1200==0:print("RETURN RIDE ",scene.player.position," raft",c," riding",rafts.riding())
  if c.x<2975 and c.x>2960 and c.z> -12500 and c.z< -12400:near=true;break
 print("BANK EDGE ",scene.player.position," raft",rafts.centre(boat)," riding",rafts.riding())
 if not check(near and rafts.riding()==boat,"raft carries player beside glacier bank"):quit(1);return
 check(scene.request_jump(),"actual sprint-jump to glacier bank")
 for tick in 240:
  var d:Vector3=Vector3(3190,0,-12190)-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>6 else Vector3.ZERO,1.0/60,true);await physics_frame
  if tick%30==0:print("BANK JUMP ",scene.player.position," region",scene.progression.region_at(scene.player.position))
  if tick>3 and scene.player.is_on_floor():break
 print("BANK LANDED ",scene.player.position)
 var region:int=scene.progression.region_at(scene.player.position)
 if not check(scene.player.position.y> -1065 and scene.player.is_on_floor(),"first landing atop original glacier bank, region"+str(region)):quit(1);return
 if not await walk(scene,[[3190,-12120],[3250,-12235],[3250,-12255],[3202,-12313],[3114,-12454],[3037,-12602],[2990,-12750],[3000,-13000]],"original ice bridge83/84/85"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_river_return_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_river_return_earned_save.json").is_empty(),"earned river return save/reload")
 check(scene.equipped_armor=="act2:L12_CM:item5" and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"earned armor/no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual niche raft jump ->physical ride ->bank jump ->original ice bridge/save-reload")
 quit(0 if failures==0 else 1)
