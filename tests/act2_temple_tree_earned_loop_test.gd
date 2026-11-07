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
 var path:="res://tmp/l8_tree_room_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="8e689f9d3aea36e46479026beef3a271a776e9e1ef849b00394eb1d45e1cbd68","qualified river return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned jungle input"):quit(1);return
 prepare(scene)
 if not await walk(scene,[[-1440,-2610]],"leave upper tree room"):quit(1);return
 if not check(scene.request_jump(),"ordinary return jump onto bridge136"):quit(1);return
 var airborne:=false;var landed:=false
 for i in 180:
  await physics_frame
  var d:Vector3=Vector3(-1335,scene.player.position.y,-2520)-scene.player.position
  scene.move_grounded(d.normalized() if d.length()>2 else Vector3.ZERO,1.0/60,true)
  if not scene.player.is_on_floor():airborne=true
  if airborne and scene.player.is_on_floor():landed=true;break
 print("RETURN TREE BRIDGE ",scene.player.position)
 if not check(landed and scene.player.position.y>225,"first landing original bridge deck"):quit(1);return
 if not await walk(scene,[[-1400,-2557]],"ordinary drop beside original bridge"):quit(1);return
 if not check(scene.player.position.y<40 and scene.resets==0,"actual ground below bridge"):quit(1);return
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_tree_to_temple.json"))
 if not await walk(scene,points,"carry same shard back to Temple"):quit(1);return
 var door=scene.get_node("L8TempleDoor");scene.camera.look_at(door.POINT,Vector3.UP)
 if not check(door.interact("enter").ok,"earned Temple entrance reused"):quit(1);return
 for i in 5:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"native Temple return command"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 if not check(change.level==14 and change.selector==1,"original Temple arrival1"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.carried_collected.count("act2:L14_HT:post_shard")==1,"same earned post shard returned to Temple once")
 check(scene.quest_state.l8_tree.lock.stone=="act2:L14_HT:post_shard" and scene.quest_state.l8_tree.lock.slots["tree:slot66"].occupied=="","tree receipt records retrieved identity")
 check(scene._quicksave_unrecorded("res://tmp/act2_temple_tree_loop_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/act2_temple_tree_loop_earned_save.json").is_empty(),"earned Temple tree loop save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned tree room -> original bridge and ordinary ground drop -> physical jungle -> native Temple return with same shard/save-reload")
 quit(0 if failures==0 else 1)
