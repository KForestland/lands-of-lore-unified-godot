extends SceneTree
func _initialize():
 run.call_deferred()
func run():
 Engine.time_scale = 1.0
 var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state = "complete"
 root.add_child(scene)
 scene.set_physics_process(false)
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/museum_stair_walk_route.json"))
 # Let the already implemented sword/table/gate sequence finish before walking.
 scene.sword_transfer.restart()
 scene.sword_transfer.advance(8.0)
 scene.museum_gate.advance(1.3)
 for i in range(60):
  await physics_frame
  scene.player.velocity = Vector3(0,-80,0)
  scene.player.move_and_slide()
 for i in range(14):
  var target := Vector2(route.points[i][0],route.points[i][1])
  var reached := false
  for step in range(360):
   await physics_frame
   var offset := target - Vector2(scene.player.position.x,scene.player.position.z)
   if offset.length() < 3:
    reached = true
    break
   var direction := offset.normalized()
   scene.player.velocity.x = direction.x * minf(80,offset.length()*60)
   scene.player.velocity.z = direction.y * minf(80,offset.length()*60)
   scene.player.velocity.y = -1 if scene.player.is_on_floor() else scene.player.velocity.y - 320.0 * scene.get_physics_process_delta_time()
   if preload("res://scripts/lol2/walk_step.gd").try_step(scene.player,Vector3(scene.player.velocity.x,0,scene.player.velocity.z)*scene.get_physics_process_delta_time()):
    scene.player.velocity.x = 0
    scene.player.velocity.z = 0
   scene.player.move_and_slide()
  if not reached:
   push_error("Walk blocked at waypoint %d target %s player %s" % [i,target,scene.player.position])
   quit(1)
   return
 scene.player.rotation = Vector3.ZERO
 scene.camera.rotation = Vector3.ZERO
 assert(scene.player.position.y > 20 and scene.player.position.y < 70)
 print("Museum stair route passed: first14 waypoints at normal physics speed")
 quit()
