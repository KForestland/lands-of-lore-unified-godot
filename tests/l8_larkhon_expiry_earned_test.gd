extends "res://tests/l12_logs_approach_earned_test.gd"
## Softlock A (DEVIATIONS 0307): earned Claw Mountains return with the dose's fall-asleep clock still running; the clock
## runs out in active world time, then the original passage must still be open, survive save/reload, and the native
## L8->L12/1 exit must still change the scene. No seeded items, position writes or forced transitions.
const Guardian=preload("res://scripts/lol2/l8_larkhon_state.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_gulch_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="6cb1e4ba6ad38bad11bf75e69aaf66636f16cefb42c07f2eaa4658b41cc956db","qualified gulch return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned jungle return input"):quit(1);return
 prepare(scene)
 var guardian=scene.get_node("L8Larkhon")
 if not check(Guardian.used(guardian.state()) and float(guardian.state().sleep)>0,"earned dose used, fall-asleep clock still running"):quit(1);return
 # Let the saved clock run out in active world time (no clock writes).
 for i in 40000:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if float(guardian.state().sleep)<=0:break
 if not check(float(guardian.state().sleep)==0.0,"sleep clock expired in active world time"):quit(1);return
 for i in 10:await physics_frame
 var blockers=scene.get_node("RegionBlockers")
 check(guardian.asleep(),"guardian keeps sleeping after the clock")
 check(scene.act2_creatures.bodies["115"].collision_layer==0,"sleeping guardian collision stays clear")
 for id in [3277,3278,3455,3456,3457]:check(not blockers.is_region_blocked(id),"passage region%d open after expiry"%id)
 check(guardian.hint.text=="","no guidance line once dosed")
 var gate_ray:=PhysicsRayQueryParameters3D.create(Vector3(7240,32,2160),Vector3(7340,32,2040),1<<9)
 check(scene.get_world_3d().direct_space_state.intersect_ray(gate_ray).is_empty(),"original passage collision clear after expiry")
 var save_path:="res://tmp/l8_larkhon_expired_earned_save.json"
 check(scene._quicksave_unrecorded(save_path).is_empty(),"expired-clock save")
 check(scene._quickload_unrecorded(save_path).is_empty(),"expired-clock reload")
 guardian=scene.get_node("L8Larkhon")
 for i in 10:await physics_frame
 check(guardian.asleep() and float(guardian.state().sleep)==0.0,"reload keeps the guardian asleep")
 for id in [3455,3456,3457]:check(not scene.get_node("RegionBlockers").is_region_blocked(id),"reloaded region%d open"%id)
 print("EXPIRY START ",scene.player.position)
 if not await walk(scene,[[7152,2236],[7195,2160],[7240,2160],[7290,2100],[7340,2040]],"expired-clock guardian exit"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"native mountain exit fired after expiry"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 check(change.level==12 and change.selector==1,"original L12 arrival1")
 var logged:int=scene.progression.native_log.size()
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change)
 check(scene.progression.native_log.size()==logged or scene.progression.native_log.back().get("type")!="closed_passage","exit not refused after expiry")
 await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 check(scene.scene_file_path=="res://scenes/lol2/maps/L12_CM.tscn","Claw Mountains reached again after the clock ran out")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no resets or seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned L12 return -> dose clock expires in active world -> passage open/save-reload -> native L12/1 again")
 quit(0 if failures==0 else 1)
