extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l8_river_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="38782a29b9e87b96a48fd64e08b18a98f9f3974a1b0542cb7c7cacec67e6ef56","qualified river return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned jungle input"):quit(1);return
 prepare(scene)
 var door=scene.get_node("L8TempleDoor")
 var before:Array=scene.carried_collected.duplicate()
 check(not door.interact("insert","act2:L13_RC:dreamstone").ok and scene.carried_collected==before,"remote stone refused without loss")
 scene.progression.use_exit("prop:1198")
 check(scene.progression.level_changes.is_empty(),"unearned Temple admission refused")
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_temple_approach.json"))
 if not await walk(scene,points,"Temple approach"):quit(1);return
 scene.camera.look_at(door.POINT,Vector3.UP)
 if not check(door.reachable(),"production Temple slot reach"):quit(1);return
 check(not door.interact("insert","act2:L13_RC:dark_sword").ok and scene.carried_collected==before,"wrong item refused without loss")
 paused=true;check(not door.interact("insert","act2:L13_RC:dreamstone").ok,"paused offer refused");paused=false
 check(not door.State.insert(door.state(),before,"act2:L13_RC:dreamstone",before.size()).ok,"full inventory refused atomically")
 if not check(door.interact("insert","act2:L13_RC:dreamstone").ok,"Kit insert actual earned Dreamstone"):quit(1);return
 check("act2:L13_RC:dreamstone" not in scene.carried_collected and not door.can_leave(),"stone occupies slot; retrieval required")
 check(scene._quicksave_unrecorded("res://tmp/l8_temple_slot_earned_save.json").is_empty(),"occupied Temple slot saved")
 check(scene._quickload_unrecorded("res://tmp/l8_temple_slot_earned_save.json").is_empty(),"occupied Temple slot reloaded")
 scene.camera.look_at(door.POINT,Vector3.UP)
 if not check(door.interact("retrieve").ok and door.can_leave(),"retrieve same earned stone"):quit(1);return
 check(scene.carried_collected.count("act2:L13_RC:dreamstone")==1,"stone not duplicated")
 if not check(door.interact("enter").ok,"actual Temple entry"):quit(1);return
 for i in 5:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"original Temple level command"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 check(change.level==14 and change.selector==1,"original L14 selector1")
 check(scene.progression.seeds_applied.is_empty(),"no jungle arrival seeds")
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene._quicksave_unrecorded("res://tmp/l14_temple_arrival_earned_save.json").is_empty(),"earned Temple arrival save")
 check(scene._quickload_unrecorded("res://tmp/l14_temple_arrival_earned_save.json").is_empty(),"earned Temple arrival reload")
 check(scene.carried_collected.count("act2:L13_RC:dreamstone")==1 and scene.equipped_armor=="act2:L12_CM:item5","stone and equipment carried into Temple")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds or recovery")
 print("TEMPLE ARRIVAL ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned river corridor -> Temple approach -> Kit Dreamstone insert/save/retrieve -> original L14 arrival/save-reload")
 quit(0 if failures==0 else 1)
