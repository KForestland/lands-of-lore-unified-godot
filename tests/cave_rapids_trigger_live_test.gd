extends SceneTree
var cave
var trigger
func _initialize() -> void:run.call_deferred()
func fail(message: String) -> void:push_error(message);quit(1)
func key(code: Key) -> void:
	var down:=InputEventKey.new();down.keycode=code;down.pressed=true;Input.parse_input_event(down);Input.flush_buffered_events();await process_frame
	var up:=InputEventKey.new();up.keycode=code;up.pressed=false;Input.parse_input_event(up);Input.flush_buffered_events();await process_frame
func click() -> void:
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);Input.flush_buffered_events();await process_frame
	var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up);Input.flush_buffered_events();await process_frame
## Supplied close pose on a source face; require an unobstructed actual ray before using input.
func aim_control() -> bool:
	for face in cave.rapids_controls.surfaces["103"]:
		var points: PackedVector3Array=face.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var center:=Vector3.ZERO
		for p in points:center+=face.mesh.to_global(p)/points.size()
		var normal: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
		for direction in [-1,1]:
			var eye: Vector3=center+normal*float(direction)*48.0
			var ray:=PhysicsRayQueryParameters3D.create(eye,center-normal*float(direction)*2.0,3,[cave.player.get_rid()])
			var hit: Dictionary=cave.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.collider!=cave.rapids_controls.bodies["103"]:continue
			cave.player.global_position=eye-Vector3.UP*24;cave.player.velocity=Vector3.ZERO
			cave.player.rotation=Vector3.ZERO;cave.camera.look_at(center,Vector3.FORWARD if absf(normal.y)>0.99 else Vector3.UP)
			return true
	return false
func complete() -> bool:
	for control in cave.rapids_controls.state.controls.values():
		if not control.complete:return false
	return true
func run() -> void:
	cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate();root.add_child(cave);current_scene=cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready:break
	if not cave.walkthrough_ready or cave.rapids_trigger==null:return fail("Rapids trigger not hosted")
	trigger=cave.rapids_trigger;cave.set_physics_process(false);cave.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var safe_position: Vector3=cave.player.global_position
	await physics_frame;await physics_frame
	if not trigger.active():return fail("Actual input world gate inactive")
	if not cave._quicksave("user://rapids_unhit.json").is_empty():return fail("Pre-hit main save failed")
	if not aim_control():return fail("No close original-control face ray")
	await click()
	if not trigger.State.released(trigger.state) or trigger.sound_starts!=1 or not trigger.voice.playing:return fail("Actual left click did not release/play sound")
	if not cave.rapids_controls.state.started or not cave.rapids_floors.state.started or cave.guard_encounter.state.definition_flags.get("28",-1)!=0:return fail("Shared command batch missing")
	if not trigger.view_effect_pending:return fail("Unimplemented original view request lost")
	if trigger.receive_spark() or trigger.sound_starts!=1:return fail("Repeat hit replayed one-shot")
	# Return to the unchanged safe start to let ordinary host physics advance the world.
	cave.player.global_position=safe_position;cave.player.velocity=Vector3.ZERO;cave.set_physics_process(true)
	for i in 60:await physics_frame
	cave.set_physics_process(false)
	if cave.cave_local7!=1 or complete():return fail("Floor/control native timing not progressive")
	if trigger.sound_time<0.8 or trigger.sound_time>1.3:return fail("Sound world clock did not advance")
	if not cave._quicksave("user://rapids_live_mid.json").is_empty():return fail("Mid-chain main save failed")
	var partial: Dictionary=cave.rapids_controls.checkpoint();var sound_at: float=trigger.sound_time
	cave.set_physics_process(true)
	for i in 900:
		await physics_frame
		if complete() and trigger.sound_time>=trigger.DURATION:break
	cave.set_physics_process(false)
	if not complete() or trigger.voice.playing or cave.cave_local7!=1:return fail("Normal physics did not finish control/audio sequence")
	if not cave._quickload("user://rapids_live_mid.json").is_empty():return fail("Mid-chain load failed")
	if cave.rapids_controls.checkpoint()!=partial or absf(trigger.sound_time-sound_at)>0.00001 or not trigger.voice.playing:return fail("Movement/audio restore differs")
	var invalid: Dictionary=cave._save_state();invalid.rapids_trigger=trigger.initial_packet()
	var f:=FileAccess.open("user://rapids_inconsistent.json",FileAccess.WRITE);f.store_string(JSON.stringify(invalid));f.close()
	if cave._quickload("user://rapids_inconsistent.json").is_empty() or cave.rapids_controls.checkpoint()!=partial:return fail("Cross-owner invalid save mutated world")
	if not cave._quickload("user://rapids_unhit.json").is_empty():return fail("Pre-hit rewind failed")
	if trigger.state.hit_mode!=0x81 or trigger.voice.playing or cave.rapids_controls.state.started or cave.rapids_floors.state.started:return fail("Rewind left effects active")
	await physics_frame;await physics_frame
	if not aim_control():return fail("Restored control no longer targetable")
	await key(KEY_1);await key(KEY_Q)
	if not trigger.State.released(trigger.state) or trigger.sound_starts!=2:return fail("Actual Q Spark did not reach control receiver")
	print("PASS live rapids: actual attack click and Q Spark from supplied source-face pose, original one-shot sound, ordinary physics floor/control completion, shared crossbow flag, main mid-motion/audio restore, inconsistent-save atomic rejection and pre-hit rewind. Owner approach, active view effect and native collision parity remain open.")
	quit()
