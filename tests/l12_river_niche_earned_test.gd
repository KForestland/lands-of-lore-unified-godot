extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_exit_cave_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="2eeacb8ec431c556f5113f4053810e946121f631ef7fbe01a5d31cdeb82e477d","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var rafts=scene.get_node("L12RiverRafts")
 if not await walk(scene,[[2480,-15680],[2365,-15740]],"river overlook edge"):quit(1);return
 var boat:=-1
 for tick in 16000:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  for i in 3:
   var c:Vector3=rafts.centre(i)
   if c.x>1995 and c.x<2010 and absf(c.z+15685)<30:boat=i;break
  if boat>=0:break
 if not check(boat>=0,"waited for an actual passing source raft"):quit(1);return
 check(scene.request_jump(),"real jump from ice opening")
 var landed:=false
 for tick in 240:
  var target:Vector3=Vector3(2220,0,-15685) if scene.player.position.y> -1050 else rafts.centre(boat)
  var d:Vector3=target-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>8 else Vector3.ZERO,1.0/60);await physics_frame
  if tick%30==0:print("DROP ",tick," ",scene.player.position," raft",rafts.centre(boat)," riding",rafts.riding())
  if rafts.riding()==boat:landed=true;break
 if not check(landed,"actual airborne drop lands on moving source raft"):quit(1);return
 var before:Dictionary=rafts.state().duplicate(true)
 paused=true
 for i in 12:await process_frame
 check(rafts.state()==before,"paused raft freezes");paused=false
 check(scene._quicksave_unrecorded("res://tmp/l12_raft_riding_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_raft_riding_save.json").is_empty(),"moving raft save/reload")
 var near:=false
 for tick in 16000:
  var c:Vector3=rafts.centre(boat)
  var target:Vector3=c+Vector3(-100,32,0) if c.x<550 and c.z< -13800 else c+Vector3.UP*32
  var d:Vector3=target-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>5 else Vector3.ZERO,1.0/60);await physics_frame
  if tick%900==0:print("RIDE ",scene.player.position," raft",c," riding",rafts.riding())
  if c.x<550 and c.z< -14100 and c.z> -14125:near=true;break
 if not check(near and rafts.riding()==boat,"actual moving raft carries Human to niche"):quit(1);return
 check(scene.request_jump(),"real Human jump from raft to niche")
 for tick in 240:
  var d:Vector3=Vector3(75,0,-14165)-scene.player.position;d.y=0
  scene.move_grounded(d.normalized() if d.length()>6 else Vector3.ZERO,1.0/60,true);await physics_frame
  if tick%30==0:print("NICHE JUMP ",scene.player.position)
  if tick>3 and scene.player.is_on_floor():break
 if not check(scene.player.position.x<160 and scene.player.position.y> -1142 and scene.player.is_on_floor(),"landed on original niche floor"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_river_niche_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_river_niche_earned_save.json").is_empty(),"earned niche save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual ice opening jump ->source raft continuous ride ->Human niche jump/save-reload")
 quit(0 if failures==0 else 1)
