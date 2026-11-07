extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_fire_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="0c758145b0c91ed3969beb1df66c19c2e6f43e8e467f08518efa08a8d52993b7","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 if not await walk(scene,[[32,-2170],[32,-2000],[-110,-1900],[-110,-1750],[-115,-1660],[-110,-1570]],"original lower exit beside upper middle corridor"):quit(1);return
 check(scene.player.is_on_floor() and absf(scene.player.position.y-192)<2,"actual lower floor160 beside slot")
 scene.camera.look_at(Vector3(-114,190,-1516),Vector3.UP)
 var ray=PhysicsRayQueryParameters3D.create(scene.camera.global_position,Vector3(-114,190,-1516),1,[scene.player.get_rid()])
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 print("SLOT APPROACH ",scene.player.position," ray ",hit)
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_flute_approach_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_flute_approach_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS three earned idols -> actual lower-side exit to angled flute slot -> save/reload")
 quit(0 if failures==0 else 1)
