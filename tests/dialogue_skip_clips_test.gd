extends SceneTree
## Enter skip for the clip owners the first skip release left out (DEVIATIONS 2026-10-22 "Not yet skippable"): the
## Cave old orc (single-pass segment; a repeating idle segment is not skipped), the captain's intro movie and his
## speech1031, the guard sequence selector clips and the guard-control clips, then the Jungle chief hut movie. Real
## Enter key events through the DialogueSkip autoload; each skip leaves the clip one step before its end and the owner's
## next tick completes it through its normal end path.
const Orc := preload("res://scripts/lol2/cave_old_orc.gd")
const Sequence := preload("res://scripts/lol2/cave_guard_sequence_state.gd")
const Controls := preload("res://scripts/lol2/cave_guard_controls_state.gd")
const STEP := 1.0 / 4096
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dialogue_skip_clips: ", message); quit(1); return false
func enter() -> void:
	var key := InputEventKey.new(); key.keycode = KEY_ENTER; key.pressed = true
	Input.parse_input_event(key); Input.flush_buffered_events()
	var up := InputEventKey.new(); up.keycode = KEY_ENTER; up.pressed = false
	Input.parse_input_event(up); Input.flush_buffered_events()
	await process_frame

func run() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false); scene.curse.set_physics_process(false)
	for name in ["old_orc", "captain", "guard_encounter", "guard_controls"]:
		var node = scene.get(name)
		if node == null or not is_instance_valid(node): return fail("Cave owner %s missing" % name)
		node.set_physics_process(false)
	# Old orc: a single-pass segment is skipped to its end; a repeating segment is not a line.
	var orc = scene.old_orc
	var single := -1
	for i in orc.source.loops.size():
		if single < 0 and Orc.segment_seconds(orc.source, i) > 0.5: single = i
	if single < 0: return fail("Old orc has no clip segment to test")
	orc.state.clip = {"segment": single, "repeat": true, "elapsed": 0.25}
	await enter()
	if float(orc.state.clip.elapsed) != 0.25: return fail("Enter skipped a repeating old orc segment")
	orc.state.clip = {"segment": single, "repeat": false, "elapsed": 0.25}
	var length: float = Orc.segment_seconds(orc.source, single)
	await enter()
	if absf(float(orc.state.clip.elapsed) - (length - STEP)) > STEP or orc.voice.playing: return fail("Old orc line not skipped (%s of %s)" % [str(orc.state.clip.elapsed), str(length)])
	orc.apply(Orc.tick(orc.state, orc.source, 1.0 / 60.0))
	if int(orc.state.clip.segment) == single and float(orc.state.clip.elapsed) < length: return fail("Old orc clip did not reach its end")
	orc.state.clip = {"segment": -1, "repeat": false, "elapsed": 0.0}
	await enter()
	# Captain intro movie, then his speech.
	var captain = scene.captain
	captain.state.movie = 0.5; captain.state.movie_done = false
	await enter()
	var end: float = ceilf(maxf(float(captain.media.duration), float(captain.media.samples) / float(captain.media.rate)) * 4096) / 4096
	if absf(float(captain.state.movie) - (end - STEP)) > STEP: return fail("Captain intro not skipped (%s)" % str(captain.state.movie))
	captain.advance(1.0 / 60.0)
	if not captain.state.movie_done: return fail("Captain intro did not complete after the skip")
	captain.state.speech = 0.2
	await enter()
	if float(captain.state.speech) < float(captain.media.speech["1031"].duration): return fail("Captain speech not skipped")
	# Guard sequence clips: each Enter ends the playing selector; the owner's next update runs the selector's callback
	# group and moves the sequencer on. Fixture: the source plate entry and render admission (the encounter state test's
	# path), validated by the owner's own restore.
	var guards = scene.guard_encounter
	var Encounter = guards.State
	var saved_packet: Dictionary = guards.checkpoint()
	var saved_position: Vector3 = scene.player.global_position
	var local7: int = int(scene.cave_local7)
	var playing: Dictionary = Encounter.initial(guards.src, guards.geometry)
	Encounter.enter(playing, guards.src, guards.geometry, Vector2(-9, -16615), -285, true, 0, local7)
	Encounter.rendered(playing, guards.src, guards.geometry, local7)
	Encounter.movie_step(playing, guards.src, guards.geometry, 0.1, local7)
	var refused_guard: String = guards.restore({"version": 1, "encounter": playing, "applied_pending": playing.pending.size(), "tick_fraction": 0.0})
	if not refused_guard.is_empty(): return fail("Guard playing fixture refused: " + refused_guard)
	if guards.state.sequence.phase != "playing" or int(guards.state.sequence.selector) != 0: return fail("Guard fixture is not playing selector 0")
	var callbacks_before: int = guards.state.groups.count(Sequence.CALLBACKS[0])
	await enter()
	var d: float = Sequence.duration(guards.src, 0)
	if absf(float(guards.state.sequence.elapsed) - (d - STEP)) > STEP or guards.movie.voice.playing: return fail("Guard clip not skipped (%s of %s)" % [str(guards.state.sequence.elapsed), str(d)])
	if int(guards.state.sequence.selector) != 0 or guards.state.groups.count(Sequence.CALLBACKS[0]) != callbacks_before: return fail("Guard skip completed the clip itself instead of leaving it to the owner")
	if not guards.active(): return fail("Guard owner inactive for its next update")
	guards.advance(1.0 / 60.0, guards.active(), local7)
	var seq: Dictionary = guards.state.sequence
	if seq.phase != "playing" or int(seq.selector) != 1 or float(seq.elapsed) <= 0.0 or float(seq.elapsed) >= 1.0 / 60.0: return fail("Guard next update did not move to selector 1 (%s %s %s)" % [str(seq.phase), str(seq.selector), str(seq.elapsed)])
	if seq.groups != Sequence.receipts(1, false): return fail("Guard selector receipts after skip: " + str(seq.groups))
	if guards.state.groups.count(Sequence.CALLBACKS[0]) != callbacks_before + 1: return fail("Guard callback group %d not applied once" % Sequence.CALLBACKS[0])
	var guard_error: String = guards.validate_packet(guards.checkpoint())
	if not guard_error.is_empty(): return fail("Guard state after skipped clip invalid: " + guard_error)
	var restored_guard: String = guards.restore(saved_packet)
	if not restored_guard.is_empty(): return fail("Guard state not restored: " + restored_guard)
	scene.player.global_position = saved_position; scene.player.velocity = Vector3.ZERO
	# Guard-control clips: Enter ends the prop533 clip; the owner's next update runs its completion group 5174.
	# Fixture: the source support109 value9 plate (beast branch) through the state's own plate().
	var controls = scene.guard_controls
	var saved_controls: Dictionary = controls.checkpoint()
	var saved_population: Dictionary = controls.population.state.duplicate(true)
	var started: Dictionary = Controls.initial()
	Controls.plate(started, controls.src, 109, 9)
	Controls.advance(started, controls.src, controls.media, 0.1)
	var refused_controls: String = controls.restore(started)
	if not refused_controls.is_empty(): return fail("Guard-control playing fixture refused: " + refused_controls)
	var clip: Dictionary = controls.state.clips["prop533"]
	if not clip.playing or clip.done: return fail("Guard-control fixture is not playing prop533")
	await enter()
	clip = controls.state.clips["prop533"]
	var cd: float = Controls.duration(controls.media, int(clip.resource))
	# The owner's present() may resume the voice at the clip clock; at most one clock step of audio may remain.
	var row: Dictionary = controls.media.clips[str(int(clip.resource))]
	var tail: float = float(row.samples) / float(row.rate) - float(clip.elapsed)
	if absf(float(clip.elapsed) - (cd - STEP)) > STEP or tail > STEP: return fail("Guard-control clip not skipped (%s of %s, voice tail %s)" % [str(clip.elapsed), str(cd), str(tail)])
	if clip.done or 5174 in controls.state.groups: return fail("Guard-control skip completed the clip itself instead of leaving it to the owner")
	if not controls.active(): return fail("Guard-control owner inactive for its next update")
	controls.advance(1.0 / 60.0)
	clip = controls.state.clips["prop533"]
	if clip.playing or not clip.done or float(clip.elapsed) != cd: return fail("Guard-control next update did not end prop533 (%s)" % str(clip))
	if controls.state.groups.count(5174) != 1 or not controls.state.events.has("actor39"): return fail("Guard-control completion group 5174 not applied: " + str(controls.state.groups))
	if controls.state.actor39.present != controls.population.state.actors["39"].present: return fail("Guard39 presence not handed to the population")
	var controls_error: String = Controls.validate(controls.checkpoint(), controls.src, controls.media)
	if not controls_error.is_empty(): return fail("Guard-control state after skipped clip invalid: " + controls_error)
	controls.population.state = saved_population; controls.population.present()
	var restored_controls: String = controls.restore(saved_controls)
	if not restored_controls.is_empty(): return fail("Guard-control state not restored: " + restored_controls)
	scene.player.global_position = saved_position; scene.player.velocity = Vector3.ZERO
	# Nobody speaking: Enter is left alone.
	var skip = root.get_node_or_null("DialogueSkip")
	if skip == null or skip.skip(): return fail("Enter was taken with nobody speaking")
	# Jungle chief hut movie.
	scene.queue_free(); await process_frame
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in range(1500):
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(false)
	var hut = scene.chief_hut
	if hut == null: return fail("Chief hut owner missing")
	hut.set_physics_process(false)
	var State = preload("res://scripts/lol2/jungle_chief_hut_state.gd")
	var movie: Dictionary = hut.checkpoint()
	movie.phase = "movie"; movie.fire_index = 8; movie.locals["10"] = 1; movie.locals["11"] = 1; movie.rock = 2; movie.movie_elapsed = 0.5
	var refused: String = hut.restore(movie)
	if not refused.is_empty(): return fail("Hut movie fixture refused: " + refused)
	await enter()
	if absf(float(hut.state.movie_elapsed) - (State.MOVIE_TIME - 1.0 / 65536)) > 1.0 / 65536: return fail("Hut movie not skipped (%s)" % str(hut.state.movie_elapsed))
	hut.advance(1.0 / 60.0)
	if hut.state.phase != "done": return fail("Hut movie did not end after the skip (%s)" % str(hut.state.phase))
	print("PASS dialogue_skip_clips: Enter ends the old orc line (not its idle loop), the captain intro and speech, guard sequence and guard-control clips, and the chief hut movie; each owner completes on its next tick; Enter with nobody speaking is left alone")
	quit(0)
