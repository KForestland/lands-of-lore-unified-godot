extends SceneTree
const Barrier = preload("res://scripts/lol2/creature_region_barrier.gd")
class Host extends Node3D:
	var player: CharacterBody3D
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok: failed=true;push_error(message)
func actor(host: Node3D, point: Vector3, layer: int) -> CharacterBody3D:
	var body:=CharacterBody3D.new();body.collision_layer=layer;body.collision_mask=1
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3.ONE*2;shape.shape=box;body.add_child(shape)
	body.position=point;host.add_child(body);return body
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var host:=Host.new();root.add_child(host)
	host.player=actor(host,Vector3(-20,10,0),1)
	var creature:=actor(host,Vector3(-20,10,5),2)
	var barrier:=Barrier.new();host.add_child(barrier)
	barrier.setup(host,{"floor":0,"ceiling":20,"polygon":[[-10,-10],[10,-10],[10,10],[-10,10]]})
	await physics_frame;await physics_frame
	check(not creature.test_move(creature.global_transform,Vector3(40,0,0)),"Open region blocks creature")
	barrier.set_enabled(true)
	await physics_frame;await physics_frame
	check(creature.test_move(creature.global_transform,Vector3(40,0,0)),"Closed region admits creature")
	check(not host.player.test_move(host.player.global_transform,Vector3(40,0,0)),"Creature-only region blocks player")
	var hit:=host.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-20,15,0),Vector3(20,15,0),1))
	check(hit.is_empty(),"Creature barrier blocks world aim ray")
	var inside:=actor(host,Vector3(0,10,0),2)
	await physics_frame;await physics_frame
	check(not inside.test_move(inside.global_transform,Vector3(20,0,0)),"Actor spawned inside cannot leave")
	inside.position=Vector3(20,10,0)
	await physics_frame;await physics_frame
	check(inside.test_move(inside.global_transform,Vector3(-40,0,0)),"Exit exemption allows re-entry")
	barrier.set_enabled(false)
	await physics_frame;await physics_frame
	check(not creature.test_move(creature.global_transform,Vector3(40,0,0)),"Restoring open state leaves barrier")
	host.queue_free();await process_frame
	if not failed:print("PASS creature_region_barrier_test: entry refused, player and aim unaffected, new inside actor can exit but not return, restore clears collision")
	quit(1 if failed else 0)
