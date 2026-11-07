extends SceneTree
## Hive Dawn20 region478 unload (source group906, pred192 local31==1): after Dawn20 appears through the RUNES entry and
## her talk ends, the player walks with the host's own grounded movement from the room's return point along the pinned
## 20-region route (tests/fixtures/hive_dawn20_region478_route.json, floor steps <= 24) into region478. Entry unloads
## her clip and records prop318 property10; the saved region edge survives disk save/load; no repeat without leaving.
## Supplied: monastery precondition globals and the nearby control0 aim (as hive_dawn20_live_test).
var scene
var d
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok

## Steers toward a route point with the host's grounded movement. An intermediate point occupied by a body (Dawn stands
## in the first route region) counts as passed once progress stalls for one second; the final point must be reached.
func walk_to(target: Vector2, tolerance: float, final: bool=false) -> bool:
	var best:=INF;var stalled:=0
	for i in 1200:
		await physics_frame
		var offset:=target-Vector2(scene.player.position.x,scene.player.position.z)
		if offset.length()<tolerance and scene.player.is_on_floor(): return true
		if offset.length()<best-0.5: best=offset.length();stalled=0
		else: stalled+=1
		if stalled>120: return not final
		var delta: float=scene.player.get_physics_process_delta_time()
		var direction:=offset.normalized()*minf(1,offset.length()/(80*delta))
		if offset.length()>1: scene.player.rotation.y=atan2(-offset.x,-offset.y)
		scene.move_grounded(Vector3(direction.x,0,direction.y),delta)
		d.advance(delta)
	return false

func run() -> void:
	var path:="user://tests/hive_dawn20_region478.json"
	Engine.physics_ticks_per_second=120
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame;await physics_frame
	scene.set_development_mode(false);scene.set_physics_process(false);scene.get_node("Warriors").set_process(false)
	root.grab_focus();await process_frame
	d=scene.dawn20;d.set_physics_process(false)
	scene.monastery_checkpoint=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	scene.monastery_checkpoint.globals.merge({"GV_HAS_RUNES":1,"GV_DAWN_ATTACKED_IN_MONASTERY":1},true)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.player.position=Vector3(-3156,-1620,-6138)
	var direction: Vector3=Vector3(-3156,-1657,-6178)-scene.camera.global_position
	scene.player.rotation.y=atan2(-direction.x,-direction.z);scene.camera.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
	await physics_frame
	if not check(scene.runes.interact(),"RUNES entry failed"):return
	scene.runes.leave()
	if not check(d.state.present and d.talking() and int(d.state.locals["31"])==1,"Dawn20 not linked"):return
	for i in 120*80:
		d.advance(1.0/120.0)
		if int(d.state.owner_state)==5 and not d.hold: break
		if i%60==0: await process_frame
	if not check(int(d.state.owner_state)==5 and not d.hold and d.state.loaded,"Talk did not reach the wait"):return
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_dawn20_region478_route.json"))
	if not check(int(route.regions[0])==679 and int(route.regions[-1])==478,"Route fixture differs"):return
	for k in range(1,route.points.size()):
		var target:=Vector2(route.points[k][0],route.points[k][1])
		if not check(await walk_to(target,40.0 if k<route.points.size()-1 else 3.0,k==route.points.size()-1),"Walk blocked at route region %s %s"%[route.regions[k],scene.player.position]):return
		if int(d.state.region)==478: break
	for i in 10: await physics_frame;d.advance(1.0/120.0)
	var foot: float=scene.player.global_position.y-d.origin().y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	if not check(int(d.state.region)==478 and not d.state.loaded and d.state.clip.is_empty() and "09033e010a00" in d.receipts,"Region478 did not unload Dawn: region=%s loaded=%s foot=%s pos=%s origin=%s"%[d.state.region,d.state.loaded,foot,scene.player.global_position,d.origin()]):return
	if not check(d.effect_log.any(func(e): return e.type=="group" and int(e.group)==906),"Group906 not run"):return
	# Edge: staying inside does not repeat; the saved region edge survives disk save/load.
	var runs: int=d.effect_log.filter(func(e): return e.type=="group" and int(e.group)==906).size()
	for i in 30: await physics_frame;d.advance(1.0/120.0)
	var se: String=scene.quicksave(path);var le: String=scene.quickload(path) if se.is_empty() else "skipped"
	scene.set_physics_process(false)
	if not check(se.is_empty() and le.is_empty() and int(d.state.region)==478 and not d.state.loaded,"Region edge save/load differs: %s %s"%[se,le]):return
	for i in 30: await physics_frame;d.advance(1.0/120.0)
	if not check(d.effect_log.filter(func(e): return e.type=="group" and int(e.group)==906).size()==runs,"Group906 repeated without leaving"):return
	scene.queue_free();for i in 3: await process_frame
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS hive dawn20 region478: Dawn20 linked via RUNES entry, talk to wait, grounded walk along %d source regions from the return point into region478 → group906 unloads her clip + prop318 receipt; edge persists over disk save/load, no repeat inside. Supplied precondition and aim."%route.regions.size())
	quit()
