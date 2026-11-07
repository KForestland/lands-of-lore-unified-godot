extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_idol_pedestals_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="76eac7615e4d04cd559a1af9757124c4da735d98a1e7013eb80a45df7411afae","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 var route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_hopper_platform_walk.json"))
 if not await walk(scene,route,"original corridor to wooden platform approach"):quit(1);return
 check(scene.player.position.z<5814,"stopped before original pressure-platform footprint")
 var ray=PhysicsRayQueryParameters3D.create(Vector3(41,350,5919),Vector3(41,200,5919),1)
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty() and absf(hit.position.y-300)<0.1,"original wooden platform floor300")
 var pop=scene.get_node("Act2Creatures")
 for id in ["91","92","93","94","95"]:print("HOPPER ",id," ",pop.state.actors[id])
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_hopper_platform_approach_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_hopper_platform_approach_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned idol stairs -> actual original corridor -> stop before wooden pressure platform/save-reload")
 quit(0 if failures==0 else 1)
