extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_temple_upper_entry_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="4d3b817fedf014e54416d7df9547ae51914d1f6e9c222e8c17375708d89635a0","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var body=scene.get_node("L14PriestBody")
 check(not body.interact("carry").ok,"remote body pickup refused")
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_priest_approach.json"))
 if not await walk(scene,points,"upper entrance priest"):quit(1);return
 scene.camera.look_at(body.START+Vector3.UP*7,Vector3.UP)
 paused=true;check(not body.interact("carry").ok,"paused carry refused");paused=false
 if not check(body.interact("carry").ok,"carry original entrance body274"):quit(1);return
 check(not body.interact("place").ok,"remote slab placement refused")
 check(scene._quicksave_unrecorded("res://tmp/l14_priest_carry_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l14_priest_carry_earned_save.json").is_empty(),"carried world body save/reload")
 points.reverse();points.append([2370,-3328])
 if not await walk(scene,points,"carry to original slab"):quit(1);return
 scene.camera.look_at(body.SLAB,Vector3.UP)
 if not check(body.interact("place").ok,"Kit placement on original rectangle"):quit(1);return
 check(not body.interact("place").ok and not body.interact("carry").ok,"no repeated body placement or duplication")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_priest_slab_earned_save.json")
 check(error.is_empty(),"placed body save: "+error)
 error=scene._quickload_unrecorded("res://tmp/l14_priest_slab_earned_save.json")
 check(error.is_empty(),"placed body reload: "+error)
 check(body.state().phase=="placed" and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"body receipt no seed/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned upper Temple -> original entrance body carry -> physical slab return/Kit placement/save-reload")
 quit(0 if failures==0 else 1)
