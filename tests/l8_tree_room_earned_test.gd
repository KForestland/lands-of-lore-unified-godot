extends "res://tests/l12_logs_approach_earned_test.gd"
func walk(scene:Node,points:Array,label:String)->bool:
 var result:bool=await super.walk(scene,points,label)
 if not result:
  for j in scene.player.get_slide_collision_count():
   var c=scene.player.get_slide_collision(j)
   print("TREE WALK BLOCK ",c.get_collider().get_path()," ",c.get_position()," ",c.get_normal())
 return result
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l8_tree_raised_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="424f9f1809a2cfa2b1bcfb41ed24e3d58116040d7677b11bf2f5cf97640e8e60","qualified river return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned jungle input"):quit(1);return
 prepare(scene)
 var tree=scene.get_node("L8Tree")
 for height in [100.0,252.0]:
  var ray:=PhysicsRayQueryParameters3D.create(Vector3(-1425,height,-2617),Vector3(-1470,height,-2646),1<<9)
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
  check(not hit.is_empty() if height==100 else hit.is_empty(),"ground strip2417 blocks below but not original upper room")
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_tree_steps.json"));points.reverse()
 if not await walk(scene,points,"raised stairs to upper bridge"):quit(1);return
 if not check(scene.player.position.y>235,"actual raised stair top210"):quit(1);return
 if not await walk(scene,[[-1300,-2510],[-1335,-2520]],"original upper bridge136"):quit(1);return
 scene.camera.look_at(tree.POINT,Vector3.UP)
 if not check(tree.reachable(),"original shard slot66 reach"):quit(1);return
 var before:Array=scene.carried_collected.duplicate()
 check(not tree.interact("insert","act2:L13_RC:dreamstone").ok and scene.carried_collected==before,"wrong Dreamstone refused without loss")
 check(not tree.Slot.insert(tree.state().lock,before,"act2:L14_HT:post_shard",before.size()).ok,"full inventory slot refusal")
 paused=true;check(not tree.interact("insert","act2:L14_HT:post_shard").ok,"paused slot refusal");paused=false
 if not check(tree.interact("insert","act2:L14_HT:post_shard").ok,"Kit inserts actual earned post shard"):quit(1);return
 check(not tree.gate.visible and "act2:L14_HT:post_shard" not in scene.carried_collected,"original bamboo door opens with occupied shard")
 check(scene._quicksave_unrecorded("res://tmp/l8_tree_occupied_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l8_tree_occupied_save.json").is_empty(),"occupied tree slot save/reload")
 if not check(scene.request_jump(),"ordinary jump from original bridge to open doorway"):quit(1);return
 var airborne:=false;var landed:=false
 for i in 180:
  await physics_frame
  var d:Vector3=Vector3(-1440,scene.player.position.y,-2610)-scene.player.position
  scene.move_grounded(d.normalized() if d.length()>2 else Vector3.ZERO,1.0/60,true)
  if i%10==0:print("TREE FLIGHT ",i," ",scene.player.position," ",scene.player.velocity)
  if i==50:
   for j in scene.player.get_slide_collision_count():
    var c=scene.player.get_slide_collision(j)
    print("TREE BLOCK ",c.get_collider().get_path()," ",c.get_position()," ",c.get_normal())
  if not scene.player.is_on_floor():airborne=true
  if airborne and scene.player.is_on_floor():landed=true;break
 print("TREE DOOR LAND ",scene.player.position)
 if not check(landed and scene.player.position.y>240,"first landing original upper doorway220"):quit(1);return
 if not await walk(scene,[[-1460,-2640]],"original upper tree room"):quit(1);return
 if not check(scene.player.position.y>240,"actual original upper room floor220"):quit(1);return
 scene.camera.look_at(tree.POINT,Vector3.UP)
 if not check(tree.interact("retrieve").ok,"retrieve same original-identity shard"):quit(1);return
 check(scene.carried_collected.count("act2:L14_HT:post_shard")==1 and not tree.interact("retrieve").ok,"no duplicate shard retrieval")
 check(scene._quicksave_unrecorded("res://tmp/l8_tree_room_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l8_tree_room_earned_save.json").is_empty(),"earned tree room save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS five earned torches -> physical raised stairs/bridge -> Kit original shard slot -> actual upper room -> same shard retrieved/save-reload")
 quit(0 if failures==0 else 1)
