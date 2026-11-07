extends "res://tests/l9_chapel_earned_test.gd"
const Club=preload("res://scripts/lol2/l8_clubhouse.gd")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l8_shaman_serum_earned_save.json","lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual shaman serum input"):quit(1);return
 prepare(scene)
 var club=scene.get_node("L8Clubhouse")
 check(not club.interact().ok,"remote clubhouse refused")
 check(not Club.validate({"version":1,"opened":true},{}).is_empty(),"membership required in saved admission")
 for id in Club.STONES:check(not scene.act2_items.take(id),"closed clubhouse refuses stone pickup")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_clubhouse_walk.json"))
 if not await walk(scene,route.points,"clubhouse guard"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l8_clubhouse_approach_earned_save.json").is_empty(),"earned clubhouse approach saved")
 scene.camera.look_at(Club.AIM,Vector3.UP)
 check(club.doors.size()==2 and club.children[51].size()>0,"original paired door geometry owned")
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(-1741,32,1020),Vector3(-1741,32,930),1)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"closed source door physically blocks entry")
 var before:Array=scene.carried_collected.duplicate()
 paused=true;check(not club.interact().ok,"paused guard refusal");paused=false
 var result:Dictionary=club.interact()
 if not check(result.ok,str(result)):quit(1);return
 check(scene.carried_collected==before,"membership opens doors without consuming items")
 check(not club.interact().ok,"doors cannot reward twice")
 for i in 10:await physics_frame
 if not await walk(scene,[[-1710,1140],[-1710,1050],[-1760,1020],[-1760,940],[-1770,870],[-1840,760],[-1880,620]],"enter clubhouse"):quit(1);return
 for id in Club.STONES:
  scene.camera.look_at(scene.act2_items.aim_point(id),Vector3.UP)
  if not check(scene.act2_items.take(id),"original clubhouse stone "+id):quit(1);return
  check(not scene.act2_items.take(id),"no duplicate stone")
 var path:="res://tmp/l8_clubhouse_earned_save.json"
 var error:String=scene._quicksave_unrecorded(path)
 check(error.is_empty(),"clubhouse save: "+error)
 if error.is_empty():check(scene._quickload_unrecorded(path).is_empty(),"clubhouse reload")
 for id in Club.STONES:check(id in scene.carried_collected and not scene.act2_items.take(id),"earned stone persisted")
 check(club.state().opened and scene.act2_creatures.state.actors["21"].health==500,"clubhouse and original guard persist")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no fall recovery or seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned shaman serum -> physical clubhouse/guard21 -> member doors51/52 -> three original stones -> save/reload")
 quit(0 if failures==0 else 1)
