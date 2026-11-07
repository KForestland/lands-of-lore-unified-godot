extends SceneTree
## Separate-process restart of the village escape (a NEW Godot process after jungle_village_escape_route_test, same user
## dir). Two kept saves, both loaded through the production quickload into a fresh Jungle host:
## 1. user://tests/village_escape_gap.json (right after Force gate and the walk through the gap, before any source relink
##    region): leaf78 unlinked (no mesh, collision layer 0, fallen leaf81 shown), leaf79 linked; Killed_Confidante,
##    GV_HULINE_ALERT, the alarm's gate targets 78/79 = 0 and local7 2 kept; grounded walking passes the leaf78 gap and
##    leaf79 still blocks.
## 2. user://tests/village_escape_final.json (at MENT): the route crossed source relink region3896, so both leaves are
##    linked again and the fallen leaves gone (kept per Codex's decision); Killed_Confidante, the alert and the alarm
##    state still persist, and the saved region history is not inside a relink region.
var scene
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func place(at: Vector2) -> void:
	var top:=Vector3(at.x,300,at.y)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*800,1,[scene.player.get_rid()]))
	scene.player.global_position=Vector3(at.x,(hit.position.y if not hit.is_empty() else 0.0)+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y)
	scene.player.velocity=Vector3.ZERO
	for i in 3: await physics_frame
func walk(to: Vector2, frames: int) -> void:
	for i in frames:
		var off:=to-Vector2(scene.player.global_position.x,scene.player.global_position.z)
		if off.length()<4: return
		scene.move_grounded(Vector3(off.x,0,off.y).normalized(),1.0/60.0)
		await physics_frame
func boot(path: String) -> bool:
	if not check(FileAccess.file_exists(path),"No kept escape save at %s (run jungle_village_escape_route_test first)"%path): return false
	if scene!=null: scene.queue_free();await process_frame;await process_frame
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.quickload(path).is_empty(),"Kept save rejected: %s"%path): return false
	while scene.monastery.active(): scene.monastery.leave_room();scene.monastery.advance(1000.0)
	scene.set_physics_process(false)
	return true
func story_kept(tag: String) -> bool:
	return check(scene.confidante.killed() and int(scene.village_gate.state().shared29)==1 and scene.village_alarm.movable_target(78)==0 and scene.village_alarm.movable_target(79)==0 and int(scene.village_alarm.state.locals["7"])==2,"%s: story/alarm state did not persist"%tag)
func run() -> void:
	# 1. Gap save: the broken leaf.
	if not await boot("user://tests/village_escape_gap.json"): return
	var body78=scene.village_gate.leaves.filter(func(b): return int(b.get_meta("source_movable"))==78)[0]
	var body79=scene.village_gate.leaves.filter(func(b): return int(b.get_meta("source_movable"))==79)[0]
	if not check(scene.village_gate.leaf_removed(78) and body78.collision_layer==0 and not body78.visible and scene.gate_leaves.panels["81"].visible and not scene.village_gate.leaf_removed(79) and body79.collision_layer==1,"Gap save: broken leaf did not persist"): return
	if not story_kept("Gap save"): return
	await place(Vector2(-1440,-5300));await walk(Vector2(-1300,-5300),900)
	if not check(scene.player.global_position.x>-1330,"Grounded walk did not pass the gap after restart: %s"%scene.player.global_position): return
	await place(Vector2(-1440,-5200));await walk(Vector2(-1300,-5200),600)
	if not check(scene.player.global_position.x<-1360,"Leaf79 stopped blocking after restart"): return
	# 2. Final save at MENT: relinked by region3896 on the way.
	if not await boot("user://tests/village_escape_final.json"): return
	if not check(not scene.village_gate.leaf_removed(78) and not scene.village_gate.leaf_removed(79) and not scene.gate_leaves.panels["81"].visible and not scene.gate_leaves.panels["80"].visible,"Final save: relinked leaves did not persist"): return
	if not check(not scene.gate_leaves.inside.any(func(r): return int(r) in [588,3895,3896,3897]),"Final save region history inside a relink region: %s"%[scene.gate_leaves.inside]): return
	if not story_kept("Final save"): return
	print("PASS jungle_village_escape_reload_test: new process: gap save keeps leaf78 broken (no mesh/collision, fallen leaf81, gap walkable, leaf79 blocks); final MENT save keeps the region3896 relink; Killed_Confidante, alert, alarm targets and local7 persist in both")
	quit()
