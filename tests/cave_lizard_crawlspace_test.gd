extends SceneTree
## Owner R19 report 10:48:34 (region631 first curse: "as a lizard go to the small opening here"). Original L1_DC
## regions 634/639/629/776/777 form a low crawlspace (floor 0, ceilings 20..80) between 635 and 778, beside region631.
## Both ends are also reachable through ordinary regions, so it is an optional shortcut, not a gate. Checks the
## production Cave player body: the lizard (cylinder r8 h8) walks 635 -> 778 through the crawlspace; the human
## (capsule r15 h46) and the beast (r23 h69) cannot enter region 634 (ceiling 40/80 sloping).
const Body := preload("res://scripts/lol2/player_form_body.gd")
const ROUTE := [Vector2(-427.8,-5979.8), Vector2(-388.8,-5939.2), Vector2(-349.2,-5916.5), Vector2(-317.0,-5916.8), Vector2(-279.0,-5935.5), Vector2(-232.2,-5991.2), Vector2(-196.2,-6074.2)]
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL cave_lizard_crawlspace: ", message); quit(1)
func place(form: int, point: Vector2) -> bool:
	scene.player.velocity = Vector3.ZERO
	scene.player.global_position = scene.native_translation + Vector3(point.x, Body.FOOT_OFFSET + 1.0, point.y)
	if not Body.apply(scene.player, scene.camera, form, false): return false
	scene.player_form = form
	for i in 4: await physics_frame
	return true
## Walk toward each waypoint with move_and_slide; returns the index of the last waypoint reached.
func walk(route: Array, speed := 60.0) -> int:
	var reached := 0
	for i in range(1, route.size()):
		var goal: Vector2 = route[i]
		var ok := false
		for frame in range(360):
			var p: Vector3 = scene.player.global_position - scene.native_translation
			var to := Vector2(goal.x - p.x, goal.y - p.z)
			if to.length() < 6.0: ok = true; break
			var dir := to.normalized()
			scene.player.velocity = Vector3(dir.x * speed, -40.0, dir.y * speed)
			scene.player.move_and_slide()
			await physics_frame
		if not ok: return reached
		reached = i
	return reached
func run() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	scene.set_physics_process(false)
	scene.curse.set_physics_process(false)
	if not await place(2, ROUTE[0]): return fail("Lizard body refused")
	var lizard := await walk(ROUTE)
	print("lizard reached waypoint ", lizard, " of ", ROUTE.size() - 1, " at ", scene.player.global_position - scene.native_translation)
	if lizard != ROUTE.size() - 1: return fail("Lizard cannot pass the crawlspace (stopped after waypoint %d)" % lizard)
	for form in [0, 1]:
		if not await place(form, ROUTE[0]): return fail("Form %d body refused" % form)
		var got := await walk(ROUTE.slice(0, 3))
		print("form ", form, " reached waypoint ", got, " at ", scene.player.global_position - scene.native_translation)
		if got >= 2: return fail("Form %d entered the crawlspace interior (region 639)" % form)
	print("PASS cave_lizard_crawlspace: lizard walks 635 -> 634/639/629/776/777 -> 778; human and beast cannot reach region 639")
	quit(0)
