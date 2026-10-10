extends SceneTree
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum);current_scene=museum
	for i in range(5): await process_frame
	museum.set_physics_process(false)
	var pop=museum.skeleton_population
	pop.set_physics_process(false)
	museum.starting_magic.set_process(false)
	var spells:=TestMagic.new();museum.add_child(spells);spells.set_process(false);museum.starting_magic=spells
	if not check(pop.state.controls=={"92":0} and not pop.state.actors["20"].woken,"Fresh control92/actor20 state differs"):return
	var control: Dictionary=pop.src.controls[0]
	var point:=Vector3(control.position[0],control.position[1],control.position[2])
	# Find a standing spot with a clear view of the exhibit.
	var placed:=false
	for angle in range(0,360,20):
		var offset:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*60
		museum.player.global_position=Vector3(point.x+offset.x,32,point.z+offset.z)
		museum.camera.look_at(point)
		await physics_frame
		if pop.aimed_control()=="92": placed=true;break
	if not check(placed and pop.control_hint()=="E — Touch the exhibit","Control92 not reachable/aimed"):return
	var event:=InputEventKey.new();event.keycode=KEY_E;event.pressed=true
	museum._unhandled_input(event)
	if not check(pop.state.controls["92"]==1 and pop.state.actors["20"].woken and pop.control_hint()=="","Control92 use did not wake actor20"):return
	var path:="user://tests/museum_control.json"
	var saved: Dictionary=pop.checkpoint()
	if not check(museum.quicksave(path).is_empty(),"Save failed"):return
	pop.state.controls["92"]=0;pop.state.actors["20"].woken=false
	if not check(museum.quickload(path).is_empty() and pop.checkpoint()==saved,"Control state lost on reload"):return
	# Legacy packets without controls load with state0.
	var legacy: Dictionary=saved.duplicate(true);legacy.erase("controls")
	if not check(Generic.validate(legacy,pop.src).is_empty() and Generic.canonical(legacy,pop.src).controls=={"92":0},"Legacy controls migration failed"):return
	DirAccess.remove_absolute(path)
	print("PASS: Museum control92 E-use (reach/aim/LOS) sets state1 and wakes skeleton20 once; disk rollback; legacy migration")
	museum.queue_free()
	await process_frame
	quit()
