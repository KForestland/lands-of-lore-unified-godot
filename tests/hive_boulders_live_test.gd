extends SceneTree
const State=preload("res://scripts/lol2/hive_boulder_actor_state.gd")
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error(message)
	quit(1)
	return false
func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		var delta: float=scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3.ZERO,delta)
		scene.boulder_surfaces._physics_process(delta)
		scene.boulders._physics_process(delta)
		scene.boulder_audio._physics_process(delta)
func freeze() -> void:
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	scene.hive_curse.set_physics_process(false)
	scene.boulder_surfaces.set_physics_process(false)
	scene.boulders.set_physics_process(false)
	scene.boulder_audio.set_physics_process(false)
func run() -> void:
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	freeze()
	await step(600)
	if not check(scene.boulders.checkpoint()==State.initial(),"Dormant source boulders fell or animated before activation"): return
	scene.player.position=Vector3(-2230,-1355,-6720)
	for i in range(100):
		await step(1)
		if scene.boulders.state.actors["30"].active: break
	await step(3)
	var actor: Dictionary=scene.boulders.state.actors["30"]
	if not check(actor.active and actor.rolling and actor.velocity_y<0 and actor.position[1]<-1207 and actor.position[1]>-1300,"Boulder source activation/midair motion failed"): return
	var path:="user://tests/hive_boulders_midfall.json"
	if not check(scene.quicksave(path).is_empty(),"Midfall boulder save failed"): return
	var partial: Dictionary=scene.boulders.checkpoint()
	var partial_handoff: Dictionary=scene.area_handoff()
	await step(40)
	var uninterrupted: Dictionary=scene.boulders.checkpoint()
	if not check(scene.quickload(path).is_empty(),"Midfall boulder load failed"): return
	freeze()
	if not check(scene.boulders.checkpoint()==partial,"Boulder restore advanced the saved sample"): return
	await step(40)
	for id in State.SPAWNS:
		var a: Dictionary=scene.boulders.state.actors[id]
		var b: Dictionary=uninterrupted.actors[id]
		if not check(a.index==b.index and a.frame==b.frame and a.timer==b.timer and absf(a.fraction-b.fraction)<0.000001,"Restored boulder path/clock diverged"): return
		for axis in range(3):
			if not check(absf(a.position[axis]-b.position[axis])<0.01,"Restored midfall position diverged"): return
	var camera_before: Transform3D=scene.camera.global_transform
	var focus: Vector3=scene.boulders.bodies["30"].global_position+Vector3.UP*20
	scene.camera.global_position=focus+Vector3(100,65,50)
	scene.camera.look_at(focus)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/hive_boulders.png")
	scene.camera.global_transform=camera_before
	var before: Dictionary=scene.boulders.checkpoint()
	paused=true
	scene.boulders._physics_process(1)
	paused=false
	if not check(scene.boulders.checkpoint()==before,"Paused boulders moved"): return
	var malformed: Dictionary=scene.area_handoff()
	malformed.quests.hive_boulder_actors.actors.erase("31")
	if not check(not scene.apply_area_handoff(malformed).is_empty() and scene.boulders.checkpoint()==before,"Partial actor packet was accepted"): return
	malformed=scene.area_handoff()
	malformed.quests.erase("hive_boulder_actors")
	if not check(not scene.apply_area_handoff(malformed).is_empty(),"New save with missing actor packet accepted as legacy"): return
	for i in range(900):
		await step(1)
		if scene.boulder_surfaces.state.phase==3: break
	if not check(scene.boulders.state.actors["30"].stopping,"Floor completion lost boulder stop request"): return
	var stop_path:="user://tests/hive_boulders_stopping.json"
	if not check(scene.quicksave(stop_path).is_empty(),"Pending-stop save failed"): return
	await step(70)
	var stopped: Dictionary=scene.boulders.checkpoint()
	if not check(not stopped.actors["30"].rolling and not stopped.actors["31"].rolling,"Boulders did not return to idle after terminal"): return
	if not check(stopped.actors["30"].index>0 and stopped.actors["31"].index>0,"Boulders never progressed along original path"): return
	if not check(scene.quickload(stop_path).is_empty(),"Pending-stop restore failed"): return
	freeze()
	await step(70)
	for id in State.SPAWNS:
		if not check(scene.boulders.state.actors[id]==stopped.actors[id],"Pending-stop restore changed final actor state"): return
	# The original floors are sloped; no final body may sink below a downward probe.
	for id in State.SPAWNS:
		var body: CharacterBody3D=scene.boulders.bodies[id]
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body.position+Vector3.UP*1,body.position-Vector3.UP*50,1,[scene.player.get_rid()]))
		if not check(not hit.is_empty() and body.position.y>=hit.position.y-0.1,"Stopped boulder has no floor support"): return
	var legacy: Dictionary=scene.area_handoff()
	legacy.quests.erase("hive_boulder_actors")
	legacy.quests.erase("hive_boulder_actor_schema")
	legacy.quests.erase("hive_boulder_contact")
	legacy.quests.erase("hive_boulder_contact_schema")
	legacy.quests.erase("hive_boulder_audio")
	legacy.quests.erase("hive_boulder_audio_schema")
	if not check(scene.apply_area_handoff(legacy).is_empty() and scene.boulders.state.legacy_retired,"Old surface-only save did not retire unavailable actor history"): return
	if not check(not scene.boulders.bodies["30"].visible,"Legacy completed trap respawned visible boulders"): return
	scene.queue_free()
	await process_frame
	await physics_frame
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene=jungle
	await process_frame
	await physics_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(partial_handoff).is_empty(),"Jungle rejected partial boulder actors"): return
	if not check(jungle.quicksave("user://tests/boulders_jungle.json").is_empty() and jungle.quickload("user://tests/boulders_jungle.json").is_empty(),"Jungle boulder disk roundtrip failed"): return
	if not check(State.canonical(jungle.area_handoff().quests.hive_boulder_actors)==partial,"Jungle changed partial boulder actors"): return
	jungle.queue_free()
	await process_frame
	print("PASS live dormant source height, activation/path/fall/frame motion, midfall and stop rollback, pause, partial-packet rejection, slope support, legacy retirement and Jungle transport; contact tested separately")
	quit()
