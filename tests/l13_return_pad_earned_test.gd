extends "res://tests/l13_altar_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_altar_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="d388d0204d82651270990c17e038177e15e05ac0744583b1dab45489a1e2b33b","qualified altar input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned altar input"):quit(1);return
 prepare(scene)
 var pad=scene.get_node("L13ReturnPad")
 check(not pad.enter(),"remote return pad refuses")
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_return_pad_walk.json"))
 if not await walk(scene,points,"original return pad54"):quit(1);return
 var items:Array=scene.carried_collected.duplicate()
 if not check(scene.request_jump(),"actual jump on source54"):quit(1);return
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if pad.state().used:break
 if not check(pad.state().used and scene.player.position.distance_to(pad.ARRIVAL)<2,"production source54 return admission"):quit(1);return
 check(scene.carried_collected==items and scene.equipped_item=="act2:L13_RC:dark_sword","return preserves earned equipment and stone")
 for i in 20:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 var error:String=scene._quicksave_unrecorded("res://tmp/l13_return_pad_earned_save.json")
 check(error.is_empty(),"return save: "+error)
 error=scene._quickload_unrecorded("res://tmp/l13_return_pad_earned_save.json");check(error.is_empty(),"return load: "+error)
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Dreamstone ->physical source54 approach/jump ->source return coordinates/equipment/save-reload")
 quit(0 if failures==0 else 1)
