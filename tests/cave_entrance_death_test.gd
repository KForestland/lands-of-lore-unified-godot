extends SceneTree
## Owner report 2026-10-17 10:45:34: walking out of the cave mouth plays no death movie. Source control135 (template21
## support plate) admits event8/9/7 for human/beast/lizard while its state is 0: immediate death + luthrdie/bst-die/
## liz-die. Actual W walking west from inside the mouth, the movie overlay, defeat, R recovery off the plate, re-arm.
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
var cave
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); quit(1)
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed; Input.parse_input_event(event)
func place(native: Vector3) -> void:
	cave.player.global_position = cave.native_translation + native; cave.player.velocity = Vector3.ZERO
	for i in range(30): await physics_frame
func walk_west(frames: int) -> int:
	var destination: Vector3 = cave.native_translation + Vector3(-1500, 0, -3144)
	key(KEY_W, true)
	var hit := -1
	for i in range(frames):
		cave.player.look_at(Vector3(destination.x, cave.player.global_position.y, destination.z)); cave.camera.rotation = Vector3.ZERO
		await physics_frame
		if cave.roach.model.player_health <= 0: hit = i; break
	key(KEY_W, false)
	return hit
func run() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(cave); current_scene = cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	if not cave.walkthrough_ready or cave.entrance_death == null or cave.roach == null: return fail("Cave entrance death owner unavailable")
	var death = cave.entrance_death
	cave.flying = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(death.SOURCE))
	if int(src.control) != 135 or src.records.size() != 3: return fail("Source plate records")
	# Inside the mouth (arrival 2 side): alive, plate not entered.
	await place(Vector3(-1250, 120, -3110))
	if cave.roach.model.player_health <= 0 or death.owner_state != 0: return fail("Spawned dead or armed state wrong")
	if death.inside(cave.player.global_position - cave.native_translation): return fail("Start pose is on the plate")
	# Human: actual W walking west onto control135.
	var frame := await walk_west(600)
	var at: Vector3 = cave.player.global_position - cave.native_translation
	print("HUMAN death frame ", frame, " at ", at)
	if frame < 0: return fail("Walking out of the cave mouth did not kill the human")
	if not death.inside(at): return fail("Death outside the source plate polygon")
	if death.owner_state != 1 or death.played != [74]: return fail("Human did not run event8 / luthrdie (%s)" % [death.played])
	if not death.playing() or not paused: return fail("Death movie overlay not playing")
	if String((death.video.stream as VideoStreamTheora).file) != String(src.movies["74"].path): return fail("Wrong human movie")
	var waited := 0
	while death.playing() and waited < 4000:
		await process_frame; waited += 1
	if death.playing() or paused: return fail("Movie did not finish and unpause")
	await physics_frame
	if not cave.defeat_notice.visible: return fail("Defeat notice missing after the movie")
	# One-shot within a life: staying on the plate does not replay.
	for i in range(20): await physics_frame
	if death.played.size() != 1: return fail("Plate replayed while state1")
	# R recovery re-arms the plate and never returns the player onto it.
	key(KEY_R, true); await process_frame; key(KEY_R, false)
	for i in range(10): await physics_frame
	at = cave.player.global_position - cave.native_translation
	if cave.roach.model.player_health <= 0: return fail("R did not recover")
	if death.owner_state != 0: return fail("R did not re-arm the plate")
	if death.inside(at): return fail("R recovered onto the death plate (%s)" % [at])
	if death.played.size() != 1: return fail("Recovery replayed the movie")
	# Beast and lizard admissions (event9 bst-die, event7 liz-die); flying/ungrounded refused.
	var top: Vector3 = Vector3(-1453, float(src.height) + FormBody.FOOT_OFFSET, -3144)
	death.reset()
	if not death.advance(top, false, 0).is_empty(): return fail("Ungrounded contact admitted")
	if not death.advance(top + Vector3(0, 12, 0), true, 0).is_empty(): return fail("Foot above tolerance admitted")
	for form_case in [[1, 11], [2, 35], [0, 74]]:
		death.reset()
		var row: Dictionary = death.advance(top, true, form_case[0])
		if row.is_empty() or int(row.movie) != form_case[1]: return fail("Form %d did not select movie %d" % form_case)
		if not death.advance(top, true, form_case[0]).is_empty(): return fail("Second frame on plate re-admitted")
	# Media are present for all three forms.
	for movie in ["74", "11", "35"]:
		if not FileAccess.file_exists(String(src.movies[movie].path)): return fail("Missing movie " + movie)
	# Save load re-arms (state is not saved; native recovery is a reload with state 0).
	death.owner_state = 1
	cave._quicksave()
	for i in range(3): await process_frame
	cave._quickload()
	for i in range(3): await process_frame
	if death.owner_state != 0: return fail("Load did not re-arm the plate")
	print("PASS cave entrance death: actual W walk out of the mouth, human luthrdie overlay, defeat, R off-plate re-arm, beast/lizard/grounded admissions, load re-arm")
	quit()
