extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_temple_arrival_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="761850f60b460772b31566ff0eb4201caba6e3d6d120ccc590bc64addb317c2f","qualified Temple arrival"):quit(1);return
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
 if not check(scene.player.position.y>30,"original upper ritual chamber floor0, not overlapping lower corridor"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l14_temple_entry_earned_save.json").is_empty(),"actual interior save")
 check(scene._quickload_unrecorded("res://tmp/l14_temple_entry_earned_save.json").is_empty(),"actual interior reload")
 check(scene.carried_collected.count("act2:L13_RC:dreamstone")==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same stone no seed/recovery")
 print("TEMPLE INSIDE ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Temple arrival -> original main doors physical passage -> retained stone/save-reload")
 quit(0 if failures==0 else 1)
