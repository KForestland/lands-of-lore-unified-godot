extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_return_descent_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="b0c5d2c2e38f275169cae11aa7223358f7057e9b4b5e7f9e9236462553323dca","qualified physical descent input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Dreamstone descent input"):quit(1);return
 prepare(scene)
 var room=scene.get_node("L13DawnPrison")
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_stone_return_dawn_walk.json"))
 if not await walk(scene,points,"earned Dreamstone to Dawn"):quit(1);return
 if not check(scene.request_jump(),"actual Dawn plate jump"):quit(1);return
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if room.entered:break
 if not check(room.entered and paused,"original Dawn room entered from physical jump"):quit(1);return
 var before:Array=scene.carried_collected.duplicate()
 check(not room.offer(scene.equipped_item).ok and scene.carried_collected==before,"actual enchanted sword refuses at stone recess")
 var stone:="act2:L13_RC:dreamstone"
 if not check(stone in scene.carried_collected and room.offer(stone).ok,"actual earned stone accepted"):quit(1);return
 check(not scene._quicksave_unrecorded("res://tmp/l13_dawn_pending_forbidden.json").is_empty(),"pending release refuses save")
 for i in 50000:
  await process_frame
  if not room.entered:break
 if not check(not room.entered and not paused and room.state().released,"full original release dialogue completes"):quit(1);return
 check(scene.carried_collected.count(stone)==1 and scene.carried_collected.count(room.Release.REWARD)==1,"same earned stone retained and single Bestial Disk gift")
 check(scene.equipped_item=="act2:L13_RC:dark_sword","enchanted equipment retained")
 var result:Dictionary=room.Release.offer(scene.quest_state[room.Release.KEY],scene.carried_collected,stone)
 check(not result.ok,"repeat release refused")
 for i in 180:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player.is_on_floor():break
 check(scene.player.is_on_floor(),"release jump settles before checkpoint")
 var error:String=scene._quicksave_unrecorded("res://tmp/l13_dawn_release_earned_save.json")
 if not check(error.is_empty(),"Dawn release save: "+error):quit(1);return
 error=scene._quickload_unrecorded("res://tmp/l13_dawn_release_earned_save.json")
 check(error.is_empty(),"Dawn release load: "+error)
 check(room.state().released and scene.carried_collected.count(stone)==1 and scene.carried_collected.count(room.Release.REWARD)==1,"release and retained item/gift persist once")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 print("DAWN released at ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned altar stone ->physical elevator return/walk ->Dawn jump ->full release ->same stone and gift/save-reload")
 quit(0 if failures==0 else 1)
