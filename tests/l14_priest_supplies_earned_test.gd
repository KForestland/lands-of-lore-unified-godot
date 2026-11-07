extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_priest_slab_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="a1c8520ef58685431ce368936974ba71d5433fee0bcf673f31fab465436223f6","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var points:Array=[[2500,-3328],[2600,-3400],[2800,-3450],[3000,-3500],[3100,-3750],[3000,-3900],[3000,-4050],[3000,-4300],[2950,-4550]]
 if not await walk(scene,points,"east then north pew room"):quit(1);return
 for id in ["act2:L14_HT:item68","act2:L14_HT:item72"]:
  var item=scene.act2_items
  if id.ends_with("item72"):
   if not await walk(scene,[[3070,-4550]],"poison supply"):quit(1);return
  scene.camera.look_at(item.aim_point(id),Vector3.UP)
  if not check(item.take(id),"actual pew item pickup "+id):quit(1);return
 points.reverse();points.append([2370,-3328])
 if not await walk(scene,points,"return supplies to priest"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l14_priest_supplies_earned_save.json").is_empty(),"actual supply save")
 check(scene._quickload_unrecorded("res://tmp/l14_priest_supplies_earned_save.json").is_empty(),"actual supply reload")
 check(scene.carried_collected.count("act2:L14_HT:item68")==1 and scene.carried_collected.count("act2:L14_HT:item72")==1,"original aloe and poison once")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS placed priest -> original east/north pew route -> original aloe68/poison72 pickup/save-reload")
 quit(0 if failures==0 else 1)
