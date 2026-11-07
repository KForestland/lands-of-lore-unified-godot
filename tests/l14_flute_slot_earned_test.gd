extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_flute_approach_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="d691b1ffa7f4de91c7fdc2cafa72771414573f9f179ac1d8f20c0850ed2fb22e","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 var slot=scene.get_node("L14FluteSlot")
 var temple:String=""
 for id in scene.carried_collected:
  if preload("res://scripts/lol2/act2_items_catalog.gd").definition(id)==96:temple=id
 check(not temple.is_empty(),"earned Temple flute exists")
 for item in ["monastery:item94:Iron_Flute",temple]:
  if not check(scene.apply_save(input.state).is_empty(),"reload actual earned input for either-flute branch"):quit(1);return
  prepare(scene);scene.camera.look_at(slot.POINT,Vector3.UP)
  for i in 2:await physics_frame
  for z in [-1232,-976]:
   var ray=PhysicsRayQueryParameters3D.create(Vector3(-60,138,z),Vector3(125,138,z),1)
   var before_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
   print("BEFORE COVER ",item," ",z," ",before_hit)
   check(before_hit.is_empty() or before_hit.collider not in [slot.parts[77].get_node("Collision"),slot.parts[78].get_node("Collision")],"oil cover initially parked away from channel")
  var before=scene.carried_collected.duplicate()
  check(not slot.interact("insert","wrong").ok,"wrong item refuses")
  check(not slot.interact("insert",item,scene.carried_collected.size()).ok,"full inventory refuses")
  paused=true;check(not slot.interact("insert",item).ok,"paused refuses");paused=false
  check(scene.carried_collected==before,"refusals preserve inventory")
  if not check(slot.interact("insert",item).ok,"either earned flute accepted: "+item):quit(1);return
  check(item not in scene.carried_collected,"Kit occupies exact flute")
  check(not slot.interact("insert",item).ok,"repeated insertion refuses")
  for i in 30:await physics_frame
  var moving:float=slot.state().covered
  paused=true
  for i in 8:await process_frame
  check(slot.state().covered==moving,"cover motion pauses");paused=false
  var err:String=scene._quicksave_unrecorded("res://tmp/l14_flute_moving_save.json")
  if not check(err.is_empty(),"moving transaction save: "+err):quit(1);return
  if not check(scene._quickload_unrecorded("res://tmp/l14_flute_moving_save.json").is_empty(),"moving transaction reload"):quit(1);return
  for i in 150:await physics_frame
  check(slot.state().covered==2,"both oil covers closed")
  for id in [77,78]:
   check(slot.parts[id].visible and slot.parts[id].position==Vector3(-195,-5,0),"original cover moved over central oil")
   check(not slot.parts[id].get_children().is_empty(),"original cover mesh and collision owned")
  for pair in [[77,-1232],[78,-976]]:
   var ray=PhysicsRayQueryParameters3D.create(Vector3(-60,138,pair[1]),Vector3(125,138,pair[1]),1)
   var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty() and hit.collider==slot.parts[pair[0]].get_node("Collision"),"original oil cover physical collision closes")
  scene.camera.look_at(slot.POINT,Vector3.UP)
  check(not slot.interact("retrieve","",scene.carried_collected.size()).ok,"full retrieval refuses")
  if not check(slot.interact("retrieve").ok,"retrieve same earned flute"):quit(1);return
  check(item in scene.carried_collected and slot.committed(slot.state()),"flute retained and oil remains covered")
  check(not slot.interact("retrieve").ok,"repeat retrieval refuses")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_flute_slot_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_flute_slot_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned either-flute Kit insert/retrieve -> original oil covers -> pause/moving-save/refusal persistence")
 quit(0 if failures==0 else 1)
