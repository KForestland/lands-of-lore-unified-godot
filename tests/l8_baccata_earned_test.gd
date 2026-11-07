extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l8_dawn_earned_save.json","lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual Dawn exchange input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_baccata_walk.json"))
 if not await walk(scene,route.points,"Baccata trap"):quit(1);return
 var approach_error:String=scene._quicksave_unrecorded("res://tmp/l8_baccata_approach_earned_save.json")
 check(approach_error.is_empty(),"approach save: "+approach_error)
 var rescue=scene.get_node("L8Baccata")
 scene.camera.look_at(rescue.AIM,Vector3.UP)
 var before:Array=scene.carried_collected.duplicate()
 check(not rescue.interact("wrong").ok and scene.carried_collected==before,"wrong cutting item refused")
 check(rescue.trapped.visible,"original pixels in logged hanging adapter")
 var result:Dictionary=rescue.interact(scene.equipped_item)
 if not check(result.ok,str(result)):quit(1);return
 check(not rescue.trapped.visible and scene.act2_creatures.bodies["116"].visible,"cut trap replaced by original standing actor116")
 var cut_error:String=scene._quicksave_unrecorded("res://tmp/l8_baccata_cut_save.json")
 if not check(cut_error.is_empty(),"cut save: "+cut_error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l8_baccata_cut_save.json").is_empty(),"cut reload")
 scene.camera.look_at(scene.act2_creatures.bodies["116"].global_position+Vector3.UP*50,Vector3.UP)
 check(rescue.interact().ok,"speak then depart")
 for i in 60:await physics_frame
 paused=true
 var elapsed:float=rescue.state().elapsed
 for i in 5:await process_frame
 check(rescue.state().elapsed==elapsed,"departure pauses")
 paused=false
 check(scene._quicksave_unrecorded("res://tmp/l8_baccata_departing_save.json").is_empty(),"departure save")
 check(scene._quickload_unrecorded("res://tmp/l8_baccata_departing_save.json").is_empty(),"departure reload")
 for i in 360:
  await physics_frame
  if rescue.state().phase==3:break
 check(rescue.state().phase==3 and not scene.act2_creatures.state.actors["116"].present,"Baccata departs once")
 check(scene.carried_collected==before,"rescue consumes no inventory or grants invented loot")
 var path:="res://tmp/l8_baccata_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"completed rescue save reload")
 check(not rescue.interact(scene.equipped_item).ok,"repeat rescue refused")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no fall reset or arrival seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Dawn shore -> physical Baccata trap route -> cut -> conversation summary -> departure with pause/mid-save/reload -> completed earned save")
 quit(0 if failures==0 else 1)
