extends SceneTree
## Modern walk feel (walk_feel.gd): off by default (Classic: instant speed, level view); on: eased start/stop and a
## view-only step bob. One walk/run pair (80/144, the Cave's) in every area; live Jungle walk and run at full speed when off.
const WalkFeel = preload("res://scripts/lol2/walk_feel.gd")
const DT := 1.0 / 60.0
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL walk_feel: ", message); quit(1)

func run() -> void:
	if WalkFeel.enabled(): return fail("modern walk feel must default to off")
	var feel = WalkFeel.new()
	var camera := Camera3D.new()
	root.add_child(camera)
	if feel.velocity(Vector2(80, 0), DT) != Vector2(80, 0): return fail("off: speed must apply at once")
	feel.bob(camera, 80.0, true, DT)
	if camera.v_offset != 0.0: return fail("off: view must not bob")

	WalkFeel.set_enabled(true, false)
	feel = WalkFeel.new()
	var first: Vector2 = feel.velocity(Vector2(80, 0), DT)
	if first.x <= 0.0 or first.x >= 20.0: return fail("on: first tick should ease in, got %s" % first)
	var ticks := 1
	while feel.planar.x < 80.0 and ticks < 60:
		feel.velocity(Vector2(80, 0), DT); ticks += 1
	if ticks > 8: return fail("on: full walk speed took %d ticks (> 0.13 s)" % ticks)
	var stop := 0
	while feel.planar.length() > 0.0 and stop < 60:
		feel.velocity(Vector2.ZERO, DT); stop += 1
	if stop > 4: return fail("on: stop took %d ticks (> 0.07 s)" % stop)

	var low := 0.0
	var high := -1.0
	for i in 60:
		feel.bob(camera, 80.0, true, DT)
		low = minf(low, camera.v_offset); high = maxf(high, camera.v_offset)
	if high > 0.0001 or low > -0.8 or low < -0.91: return fail("on: walk bob range %.3f..%.3f, expected about -0.9..0" % [low, high])
	var run_low := 0.0
	for i in 60:
		feel.bob(camera, 144.0, true, DT)
		run_low = minf(run_low, camera.v_offset)
	if run_low > -1.3: return fail("on: run bob should be deeper than walk, got %.3f" % run_low)
	if camera.position != Vector3.ZERO: return fail("bob must not move the camera node")
	for i in 30: feel.bob(camera, 0.0, true, DT)
	if camera.v_offset != 0.0: return fail("on: bob must settle when standing")
	WalkFeel.set_enabled(false, false)
	feel.bob(camera, 80.0, true, DT)
	if camera.v_offset != 0.0: return fail("switching off must clear the bob")

	var museum: Dictionary = load("res://scripts/lol2/museum_review.gd").get_script_constant_map()
	if museum.get("SPRINT_SPEED") != 144.0 or museum.get("WALK_SPEED") != 80.0: return fail("Museum walk/sprint must be 80/144 as in the Cave")

	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	for i in 60:
		scene.move_grounded(Vector3.ZERO, DT)
		await physics_frame
	var p: CharacterBody3D = scene.player
	var eye: Vector3 = scene.camera.global_position - p.global_position
	var before := p.global_position
	for i in 30:
		scene.move_grounded(Vector3(1, 0, 0), DT)
		await physics_frame
	var moved := Vector2(p.global_position.x - before.x, p.global_position.z - before.z).length()
	if absf(moved - 40.0) > 2.0: return fail("off: Jungle walk 0.5 s moved %.2f, expected 40 (instant speed)" % moved)
	if scene.camera.v_offset != 0.0 or not (scene.camera.global_position - p.global_position).is_equal_approx(eye): return fail("off: Jungle view moved")
	before = p.global_position
	for i in 30:
		scene.move_grounded(Vector3(-1, 0, 0), DT, true)
		await physics_frame
	var ran := Vector2(p.global_position.x - before.x, p.global_position.z - before.z).length()
	if absf(ran - 72.0) > 2.0: return fail("Jungle Shift run 0.5 s moved %.2f, expected 72 (144 as in the Cave)" % ran)
	print("PASS walk_feel: off by default (instant, level); on: full speed in %d ticks, stop in %d, bob -0.9 walk / %.2f run; Museum and Jungle run 144; Jungle walk %.1f, run %.1f per 0.5 s" % [ticks, stop, run_low, moved, ran])
	quit(0)
