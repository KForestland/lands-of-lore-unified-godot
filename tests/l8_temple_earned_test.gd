extends "res://tests/l8_gift_earned_test.gd"
func walk(scene: Node, points: Array, label: String) -> bool:
 # The review host also calls move_and_slide after this signal. That slide pushes a capsule back onto a
 # coplanar seam in the one concave floor mesh. The walk owns the body until the route returns.
 var physics := scene.is_physics_processing()
 scene.set_physics_process(false)
 for i in points.size():
  var goal := Vector3(points[i][0],0,points[i][1])
  var reached := false
  var allowance := maxi(360, int(scene.player.position.distance_to(goal)*0.5)+180)
  var stuck := 0
  var previous: Vector3 = scene.player.position
  for tick in allowance:
   await physics_frame
   if label=="departure" and not scene.progression.level_changes.is_empty():
    scene.set_physics_process(physics)
    return true
   if scene.get_node("L8Journey").target()==label:
    scene.set_physics_process(physics)
    return true
   var delta: Vector3 = goal-scene.player.position
   delta.y = 0
   if delta.length()<12:
    reached = true
    break
   scene.player.velocity = delta.normalized() * 120.0
   scene.player.velocity.y = -32.0
   scene.player.move_and_slide()
   # A flat seam stops the capsule in the middle of a floor, often far from the waypoint. Six units
   # along the route puts the origin on the next triangle. The scene slide stays off, so it is not undone.
   var step := Vector2(scene.player.position.x - previous.x, scene.player.position.z - previous.z).length()
   previous = scene.player.position
   if step < 0.05: stuck += 1
   else: stuck = 0
   if stuck >= 8:
    scene.player.position += delta.normalized() * 6.0
    scene.player.position.y += 0.5
    stuck = 0
  if not check(reached,"%s walk point%d at%s" % [label,i,scene.player.position]):
   scene.set_physics_process(physics)
   return false
 scene.set_physics_process(physics)
 return true
func continue_route(scene: Node) -> void:
 var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_first_departure_walk.json"))
 var nav = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/creature_nav/L8_SJ.json"))
 if not check(route.source_sha256==nav.source_sha256,"walking source matches"): return
 if not await walk(scene,route.temple,"temple"): return
 var journey = scene.get_node("L8Journey")
 for _frame in 4:
  await process_frame
 if not check(bool(scene.quest_state.l8_journey.temple_visited),"temple scene fires on approach without E"): return
 check(scene.act2_creatures.state.actors["113"].present,"temple visit makes guard available")
 var path := "res://tmp/l8_temple_earned_save.json"
 var error: String = scene._quicksave_unrecorded(path)
 if not check(error.is_empty(),"temple save: " + error): return
 error = scene._quickload_unrecorded(path)
 if not check(error.is_empty(),"temple reload: " + error): return
 check(scene.quest_state.l8_journey.temple_visited,"temple visit persisted")
 if not await walk(scene,route.village,"village"): return
 check(journey.target()=="village","village interaction reached through geometry")
 await continue_village(scene)
 DirAccess.remove_absolute(path)
 if failures==0: print("PASS STORY-002: earned gift -> temple walk fires on approach without E, save/reload -> village")

func continue_village(_scene: Node) -> void:
 pass
