extends SceneTree
const Movement=preload("res://scripts/lol2/cave_guard_movement.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var movement:=Movement.new();world.add_child(movement);assert(movement.setup(Vector3.ZERO).is_empty())
	assert(movement.bodies.size()==10)
	for id in movement.bodies:movement.bodies[id].collision_layer=512
	await physics_frame;await physics_frame
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(404,0,-16635),Vector3(404,-400,-16635),512)
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty() and hit.collider==movement.bodies["64"] and absf(hit.position.y+250)<0.01)
	assert(movement.command(64,100));assert(movement.command(73,100))
	for i in range(12):movement.advance(65536)
	var saved:=movement.checkpoint();assert(saved.objects["64"].current>0 and saved.objects["64"].current<45*65536)
	await physics_frame;await physics_frame
	hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(absf(hit.position.y-(-250+float(saved.objects["64"].current)/65536))<0.01)
	for i in range(120):movement.advance(65536)
	await physics_frame;await physics_frame
	hit=world.get_world_3d().direct_space_state.intersect_ray(ray);assert(absf(hit.position.y+205)<0.01)
	assert(absf(movement.bodies["73"].position.y-(-175-100))<0.01)
	assert(movement.restore(JSON.parse_string(JSON.stringify(saved))).is_empty())
	await physics_frame;await physics_frame
	hit=world.get_world_3d().direct_space_state.intersect_ray(ray);assert(absf(hit.position.y-(-250+float(saved.objects["64"].current)/65536))<0.01)
	var before:=movement.checkpoint();var bad:=before.duplicate(true);bad.objects["64"].target=-1;assert(not movement.restore(bad).is_empty());assert(movement.checkpoint()==before)
	print("PASS original encounter geometry: ten bodies (lever 67 and gate 71 included),48 faces, moving ray collision at initial/intermediate/end/JSON rollback, up/down endpoints, invalid restore atomic. No player riding or native collision retry claim.")
	quit()
