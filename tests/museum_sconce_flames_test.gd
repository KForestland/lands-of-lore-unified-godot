extends SceneTree
## Actual Museum host: the real Sk key in control113 shows the original template37 mask-2 fire faces
## (46 faces, resource 39, 20 pinned frames) on all 23 sconces; taking it hides them. Frames advance only
## while lit; a saved lit state restores lit through a fresh host. Supplied camera vantages.
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
const PACK := "res://assets/lol2/generated/museum_sconce_flames/"
var museum
var locks
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error(message)
		quit(1)
	return ok
func press() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	museum._unhandled_input(event)
func view(target: Vector3) -> bool:
	for distance in [45.0, 70.0, 30.0, 88.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			for lift in [0.0, -12.0, 12.0]:
				var eye: Vector3 = target + d * distance + Vector3(0, lift, 0)
				museum.player.position = eye - Vector3(0, museum.camera.position.y, 0)
				museum.camera.rotation = Vector3.ZERO
				museum.player.rotation = Vector3.ZERO
				museum.camera.look_at(target)
				await physics_frame
				if museum.can_reach_item(target): return true
	return false
func host() -> void:
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	current_scene = museum
	await process_frame
	await process_frame
	museum.set_physics_process(false)
	museum.sword_transfer.set_process(false)
	locks = museum.key_locks
func frame_index() -> int: return locks.flame_frames.find(locks.flame_material.albedo_texture)
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK + "sconce_flames.json"))
	if not check(data.faces.size() == 46 and data.frames.size() == 20 and int(data.child_mask) == 2 and int(data.resource) == 39, "Sconce pack shape"): return
	await host()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(locks.flames.size() == 23 and locks.flame_frames.size() == 20, "Source flames not built: %d" % locks.flames.size()): return
	for flame in locks.flames:
		if not check(flame.mesh.get_faces().size() == 12 and flame.material_override == locks.flame_material, "Sconce %s face pair" % flame.name): return
		if not check(not flame.visible, "Unlit sconce fire visible"): return
	var start := frame_index()
	for i in 20: await process_frame
	if not check(frame_index() == start, "Unlit fire animated"): return
	# Earn the key and light the hall through the real locks.
	if not check(await view(locks.aim_point(87)), "No vantage control87"): return
	press()
	if not check(await view(locks.aim_point(113)), "No vantage control113"): return
	press()
	if not check(State.sconces_lit(locks.state), "Sconces not lit"): return
	if not check(locks.flames.all(func(f): return f.visible), "Lit fire hidden"): return
	var seen := {frame_index(): true}
	# W5 (2026-10-31): a process-frame cap (the flames animate by the frame delta), not a wall-clock deadline.
	var budget := 240
	while seen.size() < 3 and budget > 0:
		await process_frame
		budget -= 1
		seen[frame_index()] = true
	if not check(seen.size() >= 3 and not seen.has(-1), "Lit fire frames did not advance: %s" % [seen.keys()]): return
	var path := "user://tests/sconce_flames_lit.json"
	var error: String = museum.quicksave(path)
	if not check(error.is_empty(), "Lit save: " + error): return
	# Take the key back: fire hides.
	press()
	if not check(not State.sconces_lit(locks.state) and not locks.flames.any(func(f): return f.visible), "Take left fire visible"): return
	museum.queue_free()
	await process_frame
	await host()
	error = museum.quickload(path) if museum.has_method("quickload") else "no quickload"
	if not check(error.is_empty(), "Lit load: " + error): return
	if not check(State.sconces_lit(locks.state) and locks.flames.all(func(f): return f.visible), "Lit fire not restored"): return
	print("PASS museum sconce flames: 23 sconces/46 original faces, 20 frames animate only while lit, actual key light/take, save/load restore")
	quit()
