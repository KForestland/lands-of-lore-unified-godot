extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_return_logs_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="131667f2b6b95b5b30c8380428e6bd2f9d01b5ec41f092ba21bb21b404f421c9","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var carried:Array=scene.carried_collected.duplicate();carried.sort()
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_gulch_return.json"))
 if not await walk(scene,points,"return valley and gulch"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"actual original gulch exit734"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 if not check(change.level==8 and change.selector==4,"native exit maps to original L8 arrival4"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 var after:Array=scene.carried_collected.duplicate();after.sort()
 check(carried==after,"all actually earned items survive native jungle return")
 var guardian=scene.get_node("L8Larkhon")
 check(guardian.State.used(guardian.state()) and guardian.asleep(),"earned vapors still keep the Larkhon asleep on return")
 check(scene.act2_creatures.state.actors["115"].health==5000,"guardian not seeded dead")
 var error:String=scene._quicksave_unrecorded("res://tmp/l12_gulch_return_earned_save.json")
 if not check(error.is_empty(),"jungle return save: "+error):quit(1);return
 error=scene._quickload_unrecorded("res://tmp/l12_gulch_return_earned_save.json")
 check(error.is_empty(),"jungle return reload: "+error)
 check(scene.equipped_item=="act2:L13_RC:dark_sword" and scene.equipped_armor=="act2:L12_CM:item5" and scene.carried_collected.count("act2:L12_CM:blue_bow")==1,"equipment and bow persist through jungle save")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 print("L8 RETURN ",scene.player.position," sleep",guardian.state().sleep)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned log climb ->physical reverse valley/gulch ->native L8 arrival ->sleeping guardian/equipment save-reload")
 quit(0 if failures==0 else 1)
