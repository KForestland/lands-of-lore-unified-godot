extends "res://tests/l10_tomb_earned_test.gd"
func run():
 var input:=Save.read_save("res://tmp/l9_opening_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned opening load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var bridge=scene.get_node("L9MagicBridge")
 bridge.restore()
 check(not bridge.raised(),"bridge not raised before Spark")
 check(bridge.bodies[0].collision_layer==0,"unraised bridge has no deck")
 scene.camera.look_at(bridge.AIM,Vector3.UP)
 for i in 120:
  await physics_frame
  scene.starting_magic.select_spell("spark");scene.starting_magic.cast()
  if bridge.raised():break
 if not check(bridge.raised(),"production Spark hit raises source bridge"):quit(1);return
 check(not bridge.activate(),"repeated hit cannot replay consequence")
 var path:="res://tmp/l9_bridge_raised_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty(),"raised bridge save")
 check(scene._quickload_unrecorded(path).is_empty(),"raised bridge reload")
 bridge.restore()
 check(bridge.raised() and bridge.bodies[0].collision_layer!=0,"saved bridge owns visible solid deck")
 if not await walk(scene,[[-1235,-1803],[-1320,-1803],[-1425,-1803],[-1525,-1803],[-1630,-1803],[-1710,-1803]],"raised bridge crossing"):quit(1);return
 check(scene.player.position.y>25,"crossed raised deck above gully")
 check(scene.progression.level_changes.is_empty(),"mirrors not used")
 check(scene._quicksave_unrecorded("res://tmp/l9_bridge_earned_save.json").is_empty(),"earned bridge crossing save")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned orb approach -> production Spark -> source bridge466/467 -> actual reload -> grounded crossing; mirrors not used")
 quit(0 if failures==0 else 1)
