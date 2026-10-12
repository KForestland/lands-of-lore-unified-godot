extends SceneTree
const Sequence=preload("res://scripts/lol2/hive_boulder_sequence.gd")
var groups: Array=[]
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error(message)
	quit(1)
	return false
func settle(scene: Node3D, frames: int) -> void:
	for frame in range(frames):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
func ray(scene: Node3D, a: Vector3, b: Vector3) -> Dictionary:
	return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,[scene.player.get_rid()]))
func _run() -> void:
	Engine.time_scale=4.0
	Engine.physics_ticks_per_second=240
	var scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	var controller=scene.boulder_surfaces
	controller.script_group.connect(func(group): groups.append(group))
	scene.player.position=Vector3(-2230,-1355,-6720)
	await settle(scene,25)
	if not check(controller.state.phase==1 and groups==[6778],"Grounded source trigger did not start ceiling once"): return
	await settle(scene,130)
	if not check(controller.state.phase==2 and groups==[6778,6250],"Ceiling completion did not lower floors"): return
	if not check(absf(scene.player.position.y-32.0-(-1387.0+Sequence.offsets(controller.state).floor1216))<0.4,"Player did not ride moving floor"): return
	var path="user://tests/hive_boulder_surfaces.json"
	if not check(scene.quicksave(path).is_empty(),"Partial surface disk save failed"): return
	var saved: Dictionary=controller.checkpoint()
	var saved_y: float=scene.player.position.y
	await settle(scene,15)
	if not check(scene.quickload(path).is_empty(),"Partial surface disk load failed"): return
	scene.set_physics_process(false)
	if not check(controller.state==saved and is_equal_approx(scene.player.position.y,saved_y),"Partial surface/player rollback failed"): return
	var before: Dictionary=controller.checkpoint()
	paused=true
	for frame in range(5): await process_frame
	paused=false
	if not check(controller.state==before,"Paused surface clock advanced"): return
	var bad: Dictionary=scene.area_handoff()
	bad.quests.hive_boulder_surfaces={"version":1,"phase":2,"elapsed":999}
	if not check(not scene.apply_area_handoff(bad).is_empty() and controller.state==before,"Malformed surface state was applied"): return
	await settle(scene,950)
	if not check(controller.state.phase==3 and controller.state.elapsed==Sequence.OPEN_SECONDS and groups==[6778,6250,6806],"Floor completion/exit opening callbacks incorrect"): return
	if not check(absf(scene.player.position.y-32.0+1700.0)<0.4,"Lowered floor lost grounded player"): return
	var open_exit:=ray(scene,Vector3(-2090,-1650,-6700),Vector3(-2060,-1650,-6700))
	var upper_exit:=ray(scene,Vector3(-2090,-1550,-6700),Vector3(-2060,-1550,-6700))
	var lower_west:=ray(scene,Vector3(-2370,-1600,-6700),Vector3(-2400,-1600,-6700))
	if not check(open_exit.is_empty() and not upper_exit.is_empty() and not lower_west.is_empty(),"Dynamic portal collision failed: exit/west wall"): return
	var handoff: Dictionary=scene.area_handoff()
	scene.queue_free()
	await process_frame
	await physics_frame
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene=jungle
	await process_frame
	await physics_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(handoff).is_empty(),"Jungle rejected saved surface sequence"): return
	if not check(jungle.quicksave("user://tests/hive_boulder_jungle.json").is_empty() and jungle.quickload("user://tests/hive_boulder_jungle.json").is_empty(),"Jungle disk roundtrip failed"): return
	if not check(Sequence.canonical(jungle.area_handoff().quests.hive_boulder_surfaces)==Sequence.canonical(handoff.quests.hive_boulder_surfaces),"Jungle lost saved surfaces"): return
	jungle.queue_free()
	await process_frame
	print("PASS live source surface trigger, descending floor ride, callback order, disk rollback, pause, invalid-state rejection, moving portal collisions and Jungle save transport; actor motion/contact pending")
	quit()
