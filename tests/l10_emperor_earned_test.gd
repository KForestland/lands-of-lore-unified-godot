extends "res://tests/l10_barrel_earned_test.gd"
const Emperor=preload("res://scripts/lol2/l10_emperor_state.gd")
func fight_nearby(scene: Node)->bool:
 if not check(scene.resets==0,"earned Emperor route has no resets"):return false
 return await super.fight_nearby(scene)
func input_save()->String:return "res://tmp/l10_emperor_three_globes_earned_save.json"
func approach_points()->Array:return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_emperor_walk.json")).approach.points
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual three-globe input"):quit(1);return
 prepare(scene)
 if not await walk(scene,approach_points(),"return Emperor entrance"):quit(1);return
 if not await walk(scene,[[3207,-2350],[3207,-2290],[3207,-2240],[3207,-2190],[3207,-2140],[3207,-2070],[3207,-2010],[3207,-1950],[3207,-1900],[3207,-1800],[3207,-1740],[3207,-1650]],"Emperor colour boxes"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_emperor_boxes_earned_save.json").is_empty(),"actual box approach checkpoint")
 var emperor=scene.get_node("L10Emperor")
 var ids:={"126":"act2:L10_DC:item43:charged:yellow","127":"act2:L10_DC:item8:charged:white","125":"act2:L10_DC:item9:charged:blue"}
 for target in ["126","127","125"]:
  var x: float=emperor.AIMS[target].x
  if not await walk(scene,[[x,-1650]],"matching box"+target):quit(1);return
  scene.camera.look_at(emperor.AIMS[target],Vector3.UP)
  var before: Array=scene.carried_collected.duplicate()
  check(not emperor.interact(target,Emperor.Ankh.ANKH).ok and before==scene.carried_collected,"wrong item refused without loss")
  if not check(emperor.interact(target,ids[target]).ok,"Kit matching colour "+target):quit(1);return
  var path: String="res://tmp/l10_emperor_"+target+"_occupied_earned_save.json"
  check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"partial occupied save/reload")
  scene.camera.look_at(emperor.AIMS[target],Vector3.UP)
  check(not Emperor.act(emperor.state(),scene.carried_collected,target,"",scene.carried_collected.size()).ok,"full retrieval refuses without loss")
 check(Emperor.count(emperor.state())==3,"Prima gold white blue completes set")
 if not await walk(scene,[[3135,-1650],[3135,-1510],[3207,-1450],[3207,-1360]],"inner HolyDoor143"):quit(1);return
 scene.camera.look_at(emperor.AIMS["143"],Vector3.UP)
 if not check(emperor.interact("143",Emperor.Ankh.ANKH).ok,"actual retained ankh opens inner143"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_emperor_inner_earned_save.json").is_empty(),"actual inner door checkpoint")
 if not await walk(scene,[[3207,-1300],[3207,-1270]],"original EMPT room trigger3789"):quit(1);return
 scene.camera.look_at(emperor.AIMS.remains,Vector3.UP)
 check(not Emperor.take(emperor.state(),scene.carried_collected,scene.carried_collected.size()).ok,"full reward refuses")
 if not check(emperor.interact("remains").ok,"actual room21 EMPT entry"):quit(1);return
 check(emperor.room_active and paused,"original room background pauses world")
 check(emperor.collect_remains().ok,"original sarcophagus semantic click gives def77")
 var before: Array=scene.carried_collected.duplicate()
 check(not emperor.collect_remains().ok and before==scene.carried_collected,"duplicate reward refused")
 var path:="res://tmp/l10_emperor_remains_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual remains save/reload")
 check(Emperor.REMAINS in scene.carried_collected and Emperor.BRACERS in scene.carried_collected and scene.progression.seeds_applied.is_empty(),"earned remains and bracers persist without seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned three-globe supply -> gold white blue Kit boxes partial saves -> retained ankh inner143 -> original EMPT room sarcophagus -> unique remains save/reload")
 quit(0 if failures==0 else 1)
