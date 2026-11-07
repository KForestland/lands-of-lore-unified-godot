extends SceneTree
## r12 fresh campaign leg 13 stuck at departure#116 (1322,-4360) when one-sided walls reversed the collision triangles.
## Walking from that spot to departure#116 (1286,-4271.5) on the live Jungle must arrive.
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_departure_walk_contact: ", message); quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	if not scene.one_sided_walls: return fail("Jungle walls are not one-sided")
	var p: CharacterBody3D = scene.player
	p.global_position = Vector3(1322.074, 30, -4360.762); p.velocity = Vector3.ZERO
	for i in 30: await physics_frame
	var target := Vector2(1286.0, -4271.5)
	for i in 300:
		var d := target - Vector2(p.global_position.x, p.global_position.z)
		if d.length() < 6: break
		var v := Vector3(d.x, 0, d.y).normalized() * 120.0
		p.velocity = Vector3(v.x, p.velocity.y - 9.8, v.z)
		p.move_and_slide()
		await physics_frame
	var left := (target - Vector2(p.global_position.x, p.global_position.z)).length()
	if left >= 6: return fail("Stuck %.1f from departure#116 at %s" % [left, p.global_position])
	print("PASS jungle_departure_walk_contact: one-sided walls, walked to departure#116 (%.1f left)" % left)
	quit(0)
