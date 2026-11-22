extends "res://tests/jungle_aloe_use_test.gd"
## Walk, no jump, from outside Kityara's start tiles to the r18 report pose (669,-1590).
## The shop meeting that sets Met_Kityara is jungle_kityara_live_test. This walk uses that same bank.
const Foot = preload("res://scripts/lol2/player_form_body.gd")
var k
func _ray(at: Vector2) -> Dictionary:
	var top: Vector3 = Vector3(at.x, 300.0, at.y) + k.origin()
	var query := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 800.0, 1, [scene.player.get_rid()])
	return scene.get_world_3d().direct_space_state.intersect_ray(query)
func stand(at: Vector2) -> void:
	var hit: Dictionary = _ray(at)
	var y: float = float(hit.position.y) if not hit.is_empty() else 0.0
	scene.player.global_position = Vector3(at.x, y + Foot.FOOT_OFFSET, at.y) + Vector3(k.origin().x, 0, k.origin().z)
	scene.player.velocity = Vector3.ZERO
	await physics_frame
func _native_start(at: Vector2) -> bool:
	for region in k.src.regions:
		if not k._start_region(int(region.id)): continue
		var poly := PackedVector2Array()
		for v in region.polygon: poly.append(Vector2(v[0], v[1]))
		if Geometry2D.is_point_in_polygon(at, poly): return true
	return false
func _start_distance(at: Vector2) -> float:
	var best: float = INF
	for region in k.src.regions:
		if not k._start_region(int(region.id)): continue
		var poly := PackedVector2Array()
		for v in region.polygon: poly.append(Vector2(v[0], v[1]))
		best = minf(best, k._edge_distance(at, poly))
	return best
func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var floor_ready := false
	for _i in 90:
		await process_frame
		k = scene.kityara
		if k != null and is_instance_valid(k):
			var probe: Dictionary = _ray(Vector2(669.0, -1590.6))
			if not probe.is_empty():
				floor_ready = true
				break
	freeze(scene)
	if is_instance_valid(k): k.set_physics_process(false)
	if not check(floor_ready and k != null, "Kityara or the clearing floor was not ready"): return
	scene.quest_state.monastery.globals["GV_RUNES_TRANSLATED"] = 1
	scene.quest_state.monastery.globals["GV_KITYARA_DEAD"] = 0
	scene._kityara_shop_local("Met_Kityara", 1)
	var raw: Array = k.src.locations["0"].control.position
	var kit := Vector2(float(raw[0]), float(raw[2]))
	var report := Vector2(669.0, -1590.6)
	var start: Vector2 = kit + (report - kit).normalized() * 180.0
	if not check(not _native_start(start) and _start_distance(start) > 96.0, "The walk began on a start tile or its pad"): return
	if not check(not _native_start(report) and _start_distance(report) <= 96.0, "The report pose is not in the walk-up pad"): return
	await stand(start)
	k._regions()
	if not check(k.speaking() == "" and int(k.state.locals["21"]) == 0, "The talk began before the walk"): return
	var travel: Vector2 = report - start
	var count: int = int(ceil(travel.length() / 8.0))
	var step: Vector2 = travel / float(count)
	var max_foot: float = 0.0
	for i in count:
		await stand(start + step * float(i + 1))
		var foot: float = scene.player.global_position.y - k.origin().y - Foot.FOOT_OFFSET
		max_foot = maxf(max_foot, foot)
		k._regions()
	if not check(max_foot < 8.0, "The walk left the ground"): return
	if not check(k.speaking() == "0" and int(k.state.locals["21"]) == 1 and 1324 in k.inside, "Walking to (669,-1590) did not start Kityara"): return
	print("PASS: walk with no jump from outside region 1324 to (669,-1590) starts Kityara control 0")
	quit(0)
