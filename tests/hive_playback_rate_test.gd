extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var actor = scene.get_node("ConversationReview")
	actor.set_process(false)
	assert(actor.data.fps == 15 and actor.data.get("playback_rate",1.0) == 1.0)
	actor.room_entered = true
	assert(actor.begin())
	actor.advance(2.0)
	assert(is_equal_approx(actor.elapsed,2.0) and actor.frame == 30)
	assert(actor.audio.pitch_scale == 1.0)
	var first: Dictionary = actor.data.sections[0]
	var expected_audio: float = float(first.last-first.first+1)/15.0
	assert(absf(actor.audio.stream.get_length()-expected_audio) < 0.01)
	var saved: Dictionary = actor.quest_checkpoint()
	assert(actor.restore_quest_checkpoint(saved).is_empty())
	await process_frame
	assert(actor.frame == 30 and absf(actor.audio.get_playback_position()-2.0) < 0.15)
	paused = true
	actor.advance(2.0)
	assert(actor.elapsed == 2.0)
	paused = false
	var surfaces = scene.surface_animation
	surfaces.set_process(false)
	var lava_count := 0
	for sequence in surfaces.sequences:
		sequence.elapsed = 0.0
		sequence.frame = 0
		if sequence.frames.size() == 3:
			assert(is_equal_approx(sequence.fps,1.6));lava_count += 1
		else: assert(is_equal_approx(sequence.fps,8.0))
	assert(lava_count == 3)
	surfaces.advance(0.625)
	for sequence in surfaces.sequences:
		if sequence.frames.size() == 3: assert(sequence.frame == 1)
	scene.queue_free()
	await process_frame
	print("PASS: normal-speed dialogue frame/audio resume, pause, and one-fifth-speed lava playback")
	quit(0)
