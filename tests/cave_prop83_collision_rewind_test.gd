extends SceneTree
const State = preload("res://scripts/lol2/cave_prop83_lift_state.gd")
func _initialize(): run.call_deferred()
func run():
 var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
 root.add_child(cave); current_scene = cave
 for i in 600:
  await process_frame
  if cave.walkthrough_ready: break
 cave.set_physics_process(false)
 var lift = cave.prop83_lift
 lift.set_physics_process(false)
 var center: Vector3 = lift.body.global_position
 var ray = PhysicsRayQueryParameters3D.create(center+Vector3(30,0,0),center-Vector3(30,0,0),2,[cave.player.get_rid()])
 await physics_frame
 var space = cave.get_world_3d().direct_space_state
 assert(space.intersect_ray(ray).get("collider") == lift.body,"Initial trigger collider missing")
 var open = State.initial(); open.state=1; open.opened=true
 assert(lift.restore(open).is_empty())
 await physics_frame
 await physics_frame
 if space.intersect_ray(ray).get("collider") == lift.body:
  push_error("Removed prop83 still blocks the player")
  quit(1)
  return
 assert(lift.restore(State.initial()).is_empty())
 await physics_frame
 await physics_frame
 assert(space.intersect_ray(ray).get("collider") == lift.body,"Rewind lost trigger collider")
 print("PASS prop83 collision: present before chain, absent after removal, restored on rewind")
 quit()
