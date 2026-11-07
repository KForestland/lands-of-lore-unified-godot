extends SceneTree
## Owner F10 2026-10-24 17:53 (human form, map 784,1215): "i fall true the birghe". The river bridge deck (scripted
## solid assemblies 213/214/210/212, top at bank height 0 over the -90 river bed) had no collision. Walking the deck
## from the west bank to the east bank on the live Jungle must stay on it.
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_bridge_deck: ", message); quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	for id in scene.JUNGLE_BRIDGE:
		if not scene.static_assemblies.solid_bodies.has(id): return fail("Bridge assembly %d has no solid" % id)
	var p: CharacterBody3D = scene.player
	p.global_position = Vector3(760.0, 30.0, 1207.0); p.velocity = Vector3.ZERO
	for i in 30: await physics_frame
	var target := Vector2(1950.0, 1207.0)
	var lowest := p.global_position.y
	for i in 900:
		var d := target - Vector2(p.global_position.x, p.global_position.z)
		if d.length() < 6: break
		var v := Vector3(d.x, 0, d.y).normalized() * 120.0
		p.velocity = Vector3(v.x, p.velocity.y - 9.8, v.z)
		p.move_and_slide()
		lowest = minf(lowest, p.global_position.y)
		await physics_frame
	var left := (target - Vector2(p.global_position.x, p.global_position.z)).length()
	if lowest < -20.0: return fail("Fell off the deck: lowest y %.1f at %s" % [lowest, p.global_position])
	if left >= 6: return fail("Stuck %.1f from the east bank at %s" % [left, p.global_position])
	print("PASS jungle_bridge_deck: crossed the river on the deck (lowest y %.1f)" % lowest)
	quit(0)
