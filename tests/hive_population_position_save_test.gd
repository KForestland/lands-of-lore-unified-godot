extends SceneTree
const State=preload("res://scripts/lol2/hive_return_population_state.gd")
class Host extends Node3D:
	var player:=CharacterBody3D.new()
	var camera:=Camera3D.new()
class Population extends "res://scripts/lol2/hive_return_population.gd":
	func _ready() -> void: pass
	func active() -> bool: return true
	func present() -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var host:=Host.new();root.add_child(host)
	host.add_child(host.player);host.add_child(host.camera)
	var floor_body:=StaticBody3D.new();host.add_child(floor_body)
	var floor_shape:=CollisionShape3D.new();floor_body.add_child(floor_shape)
	var floor_box:=BoxShape3D.new();floor_box.size=Vector3(2000,2,2000);floor_shape.shape=floor_box
	floor_body.position.y=-1
	var pop:=Population.new();host.add_child(pop);pop.host=host;pop.set_physics_process(false)
	var body:=CharacterBody3D.new();host.add_child(body);body.position=Vector3(0,35.001,0)
	var shape:=CollisionShape3D.new();body.add_child(shape)
	var box:=BoxShape3D.new();box.size=Vector3(10,70,10);shape.shape=box
	pop.bodies["23"]=body;pop.state.actors["23"].active=true
	for i in range(180):
		host.player.position=body.position+Vector3(150,0,73)
		host.camera.position=host.player.position
		await physics_frame
		pop.advance(1.0/60.0)
		var saved: Dictionary=pop.checkpoint()
		var restored:=State.canonical(JSON.parse_string(JSON.stringify(saved)))
		if restored!=saved:
			push_error("Pursuit position changed in JSON at step %d"%i);quit(1);return
		assert(State.validate(restored).is_empty())
		var p: Array=saved.actors["23"].position
		assert(Vector3(p[0],p[1]+35,p[2]).distance_to(body.position)<0.014)
	assert(body.position.x>50)
	host.queue_free();await process_frame
	print("PASS: 180 production pursuit updates on collision floor, exact JSON population round trips and sub-0.014-unit position error")
	quit()
