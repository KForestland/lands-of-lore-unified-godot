extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l8_baccata_earned_save.json","lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual Baccata rescue input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_silverleaf_return_walk.json"))
 if not await walk(scene,route.jungle.points,"Cemetery return"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"native cemetery entrance"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 check(change.level==10 and change.selector==1,"native cemetery1 destination")
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene._quicksave_unrecorded("res://tmp/l10_silverleaf_arrival_earned_save.json").is_empty(),"earned cemetery arrival checkpoint")
 var growth=scene.get_node("L10Silverleaf")
 check(not growth.state().grown,"no premature Silverleaf")
 check(not growth.revisit().ok,"remote Emperor interaction refused")
 if not await walk(scene,route.cemetery.points,"Emperor revisit"):quit(1);return
 var emperor=scene.get_node("L10Emperor")
 scene.camera.look_at(emperor.AIMS.remains,Vector3.UP)
 var before:Array=scene.carried_collected.duplicate()
 var result:Dictionary=emperor.interact("remains")
 if not check(result.ok,str(result)):quit(1);return
 check(growth.state().grown,"failed dead-speech encounter activates original trees")
 for id in growth.TREES:
  var row:Array=scene.prop_placements[id]
  check(row[0].get_instance_transform(row[1]).basis.determinant()!=0,"tree grown "+str(id))
 check(scene.carried_collected==before,"growth does not inject leaves or return bracers")
 check(not emperor.interact("remains").ok,"repeat encounter cannot repeat growth")
 var path:="res://tmp/l10_silverleaf_growth_earned_save.json"
 var error:String=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"growth save: "+error)
 if error.is_empty():check(scene._quickload_unrecorded(path).is_empty(),"growth reload")
 check(growth.state().grown and scene.carried_collected==before,"growth persists without reward replay")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no resets or seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned rescue -> native cemetery return -> physical Emperor revisit without bracers ->12 original Silverleaf tree props grow -> save/reload")
 quit(0 if failures==0 else 1)
