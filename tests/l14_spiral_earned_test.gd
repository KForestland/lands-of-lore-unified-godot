extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_shard_bowls_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="451c0688afcf2025991114469695bf24753d735565b59d446cb9ace70818e1bc","qualified bowl passage"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned bowl passage input"):quit(1);return
 prepare(scene)
 var spiral=scene.get_node("L14Spiral")
 var slot_ray=PhysicsRayQueryParameters3D.create(Vector3(630,40,-3464),Vector3(580,40,-3464),1)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(slot_ray).is_empty(),"original Dreamstone slot geometry remains collidable")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_spiral_walk.json"))
 var stone:=""
 for id in scene.carried_collected:
  if preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==136:stone=id;break
 if not check(not stone.is_empty(),"actual earned Dreamstone retained"):quit(1);return
 check(not spiral.interact("insert",stone).ok,"remote insertion refused")
 if not await walk(scene,route.approach,"original Dreamstone slot72"):quit(1);return
 scene.camera.look_at(spiral.POINT,Vector3.UP)
 check(not spiral.interact("insert","act2:L14_HT:item77").ok,"wrong flute refused")
 check(not spiral.interact("insert",stone,scene.carried_collected.size()).ok,"full inventory refused without stone loss")
 paused=true;check(not spiral.interact("insert",stone).ok,"paused insertion refused");paused=false
 if not check(spiral.interact("insert",stone).ok,"Kit earned Dreamstone in original72"):quit(1);return
 check(not spiral.interact("insert",stone).ok,"duplicate insertion refused")
 for i in 60:await physics_frame
 var before:float=spiral.state().raised
 paused=true
 for i in 10:await process_frame
 check(spiral.state().raised==before,"spiral clock pauses")
 paused=false
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_spiral_moving_save.json")
 if not check(error.is_empty(),"moving spiral save: "+error):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_spiral_moving_save.json").is_empty(),"moving spiral reload"):quit(1);return
 scene.camera.look_at(spiral.POINT,Vector3.UP)
 check(not spiral.interact("retrieve","",scene.carried_collected.size()).ok,"full retrieval refused without loss")
 if not check(spiral.interact("retrieve").ok,"retrieve same earned Dreamstone"):quit(1);return
 check(not spiral.interact("retrieve").ok,"retrieval cannot duplicate stone")
 for i in 300:await physics_frame
 check(spiral.state().raised==4 and stone in scene.carried_collected,"completed spiral and retained stone")
 for point in [Vector3(35,350,-3433),Vector3(26,350,-3638),Vector3(155,350,-3638)]:
  var ray=PhysicsRayQueryParameters3D.create(point,point-Vector3(0,600,0),1)
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
  print("SPIRAL FLOOR ",point," ",hit.get("position"))
  check(not hit.is_empty() and hit.position.y>0,"original spiral floor actually raised")
 if not await walk(scene,route.entry,"original outer spiral room"):quit(1);return
 if not await walk(scene,route.spiral,"original rising spiral floors"):quit(1);return
 if not check(scene.player.is_on_floor() and scene.player.position.y>225,"actual spiral upper floor200"):quit(1);return
 if not await walk(scene,route.bridge,"original bridge167 to three doors"):quit(1);return
 check(scene.player.is_on_floor() and scene.player.position.y>215,"actual three-door room floor190")
 error=scene._quicksave_unrecorded("res://tmp/l14_spiral_earned_save.json")
 if not check(error.is_empty(),"three-door approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_spiral_earned_save.json").is_empty(),"three-door approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/teleport/recovery")
 print("THREE DOORS APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned bowl passage -> Kit Dreamstone slot72/retrieval -> original spiral/bridge walk -> three-door room/save-reload")
 quit(0 if failures==0 else 1)
