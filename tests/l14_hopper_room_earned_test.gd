extends "res://tests/l12_logs_approach_earned_test.gd"
var observed:Node
var stepped:bool=false
func watch_platform():
 if not is_instance_valid(observed):return
 var p:Vector3=observed.player.position
 if p.x>=-35 and p.x<=115 and p.z>=5814 and p.z<=6026 and p.y-32>=295:stepped=true
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_hopper_platform_approach_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="172bd859e79a83273fefcaf189fa8581e210d5ef70e6b134f23413a162dc81fe","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 observed=scene;physics_frame.connect(watch_platform)
 if not await walk(scene,[[-47,5770]],"near side-ledge jump approach"):quit(1);return
 if not check(scene.request_jump(),"ordinary jump onto widened middle of source side ledge"):quit(1);return
 if not await walk(scene,[[-47,5890],[-47,5935]],"original side ledge midpoint"):quit(1);return
 if not check(scene.request_jump(),"ordinary jump off side ledge to far landing"):quit(1);return
 if not await walk(scene,[[-30,6070],[40,6150],[40,6320],[40,6600],[40,6650]],"far platform landing and hopper room"):quit(1);return
 check(scene.player.position.y>330 and scene.player.position.y<335,"remained on original raised gallery floor300")
 check(not stepped,"never stood inside original pressure-platform footprint")
 var pop=scene.get_node("Act2Creatures")
 for id in ["91","92","93","94","95"]:print("HOPPER ",id," ",pop.state.actors[id])
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_hopper_room_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_hopper_room_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned platform approach -> actual side ledge without stepping on platform -> raised hopper gallery/save-reload")
 quit(0 if failures==0 else 1)
