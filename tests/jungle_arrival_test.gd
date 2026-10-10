extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var scene = load("res://scenes/lol2/jungle_review.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 assert(scene.ready_for_review and scene.face_count == 10476)
 assert(scene.start == Vector3(353,75,-4909))
 for i in range(90): await physics_frame
 assert(scene.player.is_on_floor())
 assert(scene.player.position.y > 70 and scene.player.position.y < 75)
 assert(scene.resets == 0)
 var ray = PhysicsRayQueryParameters3D.create(Vector3(353,100,-4909),Vector3(353,0,-4909))
 ray.exclude = [scene.player.get_rid()]
 var hit = scene.get_world_3d().direct_space_state.intersect_ray(ray)
 assert(not hit.is_empty() and hit.position.y >= 39 and hit.position.y <= 41)
 print("Jungle arrival settled: ",scene.player.position,"; source floor: ",hit.position.y)
 if "--capture-jungle" in OS.get_cmdline_user_args():
  scene.camera.rotation.x = -0.5
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/home/bob/lol2_out/jungle_geometry_20260914/godot_arrival.png")
  scene.camera.rotation.x = 1.3
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/home/bob/lol2_out/jungle_geometry_20260914/godot_sky.png")
 quit()
