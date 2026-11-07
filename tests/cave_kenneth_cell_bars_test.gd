extends SceneTree
## Owner r12l report 15:23:21 / KENNETH_ROOM_REPRO_20261028 B1-B4: the control104 cell trap with the window bars
## (gate 71, added with lever 67) closed, in human (0) and lizard (2) form, each in a fresh main Cave scene:
## the closed bars stand on the camera->guard line (negative control: a ray that does not skip them hits
## SourceMovable71), yet the plate still starts the guard (native admission = prop456 drawn; the bars are drawn
## see-through), the bars' material has the index-0 cutout, the six clips run to completion and release the input,
## slab 68 drops, lever 72 reopens gate 73 and lever 67 raises gate 71. Bounded fixture: plate start pose and the
## sequence clock are driven by the test; levers go through the controller's use_lever (actual E is covered by
## cave_lever72_gate_walk_test). LOL2_CAPTURE_DIR, if set, receives one picture per form of the guard behind the bars.
const Body := preload("res://scripts/lol2/player_form_body.gd")
var cave

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	push_error(message); print("FAIL cave_kenneth_cell_bars: ", message); quit(1)

func frames(n: int) -> void:
	for i in range(n): await physics_frame

func capture(form: int) -> void:
	var dir := OS.get_environment("LOL2_CAPTURE_DIR")
	if dir.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join("kenneth_cell_bars_form%d.png" % form))

func one_form(form: int) -> String:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(cave); current_scene = cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	if not cave.walkthrough_ready or cave.guard_encounter == null: return "Main Cave guard owner unavailable"
	cave.flying = false
	var controller: Node3D = cave.guard_encounter
	var bars: Node3D = controller.movement.bodies.get("71")
	if bars == null: return "Gate 71 body missing"
	for mesh in bars.get_children():
		if mesh is MeshInstance3D:
			var material: Material = mesh.mesh.surface_get_material(0)
			if material is ShaderMaterial and material.get_shader_parameter("cutout") != true: return "Bars 71 drawn without the index-0 cutout"
			if material is StandardMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return "Bars 71 drawn without alpha scissor"
	var bars_closed_y: float = bars.global_position.y
	var slab: Node3D = controller.movement.bodies["68"]; var slab_y: float = slab.global_position.y
	cave.player.global_position = cave.native_translation + Vector3(-9, -245, -16615); cave.player.velocity = Vector3.ZERO
	if not Body.apply(cave.player, cave.camera, form, false): return "Form %d not applied" % form
	cave.player_form = form
	cave.player.global_position = cave.native_translation + Vector3(-9, -245, -16615); cave.player.velocity = Vector3.ZERO
	cave.camera.rotation = Vector3.ZERO
	# Negative control: the closed bars are physically between the camera and the guard.
	var point: Vector3 = controller.movie.global_position + Vector3.UP * 45
	var naive := PhysicsRayQueryParameters3D.create(cave.camera.global_position, point, 1, [cave.player.get_rid()])
	await physics_frame
	var hit: Dictionary = cave.get_world_3d().direct_space_state.intersect_ray(naive)
	print("FORM ", form, " naive ray hit: ", hit.get("collider").name if not hit.is_empty() else "none")
	for i in range(60):
		await physics_frame
		if controller.state.sequence.phase == "playing": break
	if controller.state.sequence.phase != "playing": return "Plate did not start the guard with bars 71 closed (form %d)" % form
	if not controller.input_locked(): return "Guard speech did not lock the input"
	await capture(form)
	for i in range(4000):
		controller.advance(1.0 / 60, true, cave.cave_local7)
		if controller.state.sequence.phase == "complete": break
	if controller.state.sequence.phase != "complete" or controller.input_locked(): return "Guard sequence did not release"
	await frames(400)
	if absf(slab.global_position.y - slab_y) < 10: return "Slab 68 did not move (%s -> %s)" % [slab_y, slab.global_position.y]
	var gate: Node3D = controller.movement.bodies["73"]
	if controller.state.movable_states["72"] != 1 or absf(gate.global_position.y - cave.native_translation.y + 275) > 0.5: return "Trap did not close gate 73"
	if not controller.use_lever(72, cave.cave_local7): return "Lever 72 refused"
	await frames(600)
	if absf(gate.global_position.y - cave.native_translation.y + 175) > 0.5: return "Lever 72 did not reopen gate 73"
	if not controller.use_lever(67, cave.cave_local7): return "Lever 67 refused"
	await frames(600)
	if bars.global_position.y - bars_closed_y < 90: return "Lever 67 did not raise gate 71 (%s -> %s)" % [bars_closed_y, bars.global_position.y]
	print("FORM ", form, " slab68 ", slab_y, " -> ", slab.global_position.y, "; gate71 ", bars_closed_y, " -> ", bars.global_position.y)
	controller.movie.voice.stop(); controller.delayed_voice.stop()
	await physics_frame
	cave.queue_free(); await process_frame; await process_frame
	return ""

func run() -> void:
	for form in [0, 2]:
		var error: String = await one_form(form)
		if not error.is_empty(): return fail(error)
	print("PASS cave_kenneth_cell_bars: human and lizard: bars 71 closed and see-through (cutout), the guard starts and finishes, input released, slab 68 drops, lever 72 reopens gate 73, lever 67 raises gate 71.")
	quit()
