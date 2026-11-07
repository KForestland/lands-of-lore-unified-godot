extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/act2_temple_tree_loop_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="ecf444a845abbb932d11af55d883bb4ef99a0688997dffe9a8c491ba90457846","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var doors=scene.get_node("L14TempleDoors")
 check(not doors.gate.visible and doors.gate.get_node("Collision").collision_layer==0,"earned receipt opens original doors92/93")
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_entry_walk.json"))
 if not await walk(scene,points,"original main doors"):quit(1);return
 var hanging=scene.get_node("L14Hanging")
 check(not hanging.interact().ok,"remote hanging refused")
 if not await walk(scene,[[2400,-3450],[2400,-3550],[2350,-3610],[2315,-3660]],"left hanging approach"):quit(1);return
 scene.camera.look_at(hanging.POINT,Vector3.UP)
 paused=true;check(not hanging.interact().ok,"paused hanging refused");paused=false
 if not check(hanging.interact().ok,"open original left hanging124"):quit(1);return
 check(not hanging.interact().ok,"repeat opening refused")
 if not await walk(scene,[[2220,-3750],[2170,-3800]],"cross original hanging"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l14_hanging_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l14_hanging_earned_save.json").is_empty(),"open passage save/reload")
 check(hanging.state().opened and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"opened hanging no seed/recovery")
 print("HANGING EXIT ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Temple return -> left hanging124 -> physical secret passage/save-reload")
 quit(0 if failures==0 else 1)
