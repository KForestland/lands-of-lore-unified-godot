extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_idol_room_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="222f13ddfeba61e4bef15544cf167e19c21a76558a850a3b81c3df9230998655","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 var ped=scene.get_node("L14IdolPedestals")
 check(not ped.offer("85",ped.IDOLS[0]).ok,"remote pedestal refuses")
 var steps:Array=[["87",[-100,3505],ped.IDOLS[2]],["85",[110,3510],ped.IDOLS[0]],["86",[19,3590],ped.IDOLS[1]]]
 for step in steps:
  if not await walk(scene,[step[1]],"original idol pedestal "+step[0]):quit(1);return
  scene.camera.look_at(ped.CASES[step[0]],Vector3.UP)
  var before=scene.carried_collected.duplicate()
  check(not ped.offer(step[0],"wrong").ok,"wrong item refuses")
  check(not ped.offer(step[0],step[2],scene.carried_collected.size()).ok,"full inventory refuses")
  paused=true;check(not ped.offer(step[0],step[2]).ok,"paused pedestal refuses");paused=false
  check(scene.carried_collected==before,"refusals preserve all earned inventory")
  if not check(ped.offer(step[0],step[2]).ok,"distinct earned idol placed"):quit(1);return
  check(step[2] not in scene.carried_collected,"exact idol occupied in Kit slot")
  check(not ped.offer(step[0],step[2]).ok,"duplicate placement refuses")
  if step[0]!="86":check(ped.state().assembled==0,"fewer than three leave stairs parked")
 for i in 60:await physics_frame
 var moving:float=ped.state().assembled
 paused=true
 for i in 8:await process_frame
 check(ped.state().assembled==moving,"stair motion pauses");paused=false
 var err:String=scene._quicksave_unrecorded("res://tmp/l14_idol_stairs_moving_save.json")
 if not check(err.is_empty(),"moving stair save: "+err):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_idol_stairs_moving_save.json").is_empty(),"moving stair reload"):quit(1);return
 for i in 300:await physics_frame
 check(ped.state().assembled==4,"fourteen original stairs assembled")
 for pair in [[3750,157],[4208,277]]:
  var ray=PhysicsRayQueryParameters3D.create(Vector3(32,300,pair[0]),Vector3(32,-200,pair[0]),1)
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
  check(not hit.is_empty() and absf(hit.position.y-pair[1])<0.1,"actual original stair height retained")
 if not await walk(scene,[[32,3730],[32,3789],[32,3850],[32,3918],[32,3979],[32,4042],[32,4096],[32,4151],[32,4208],[32,4260]],"actual assembled original staircase crossing"):quit(1);return
 check(scene.player.position.y>310 and scene.player.position.y<320,"actual far floor281 reached")
 for id in ped.IDOLS:check(id not in scene.carried_collected,"three idols remain on distinct pedestals")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_idol_pedestals_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_idol_pedestals_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS three earned idols -> distinct Kit pedestals -> fourteen original moving stairs -> actual far-floor crossing/save-reload")
 quit(0 if failures==0 else 1)
