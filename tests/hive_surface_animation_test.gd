extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	var animation = scene.surface_animation
	assert(animation.sequences.size() == 4)
	animation.set_process(false)
	for sequence in animation.sequences:
		assert(sequence.frames.size() > 1)
		assert(sequence.material.albedo_texture == sequence.frames[0])
	var initial_position = scene.player.position
	animation.advance(0.125)
	for sequence in animation.sequences:
		assert(sequence.frame == 1)
		assert(sequence.material.albedo_texture == sequence.frames[1])
		assert(sequence.frames[0].get_image().get_data() != sequence.frames[1].get_image().get_data())
	animation.advance(-1.0)
	for sequence in animation.sequences: assert(sequence.frame == 1)
	animation.advance(3.625) # Thirty frames total: whole cycles for 3/10-frame resources.
	for sequence in animation.sequences: assert(sequence.frame == 0)
	assert(scene.player.position == initial_position)
	animation.set_process(true)
	paused = true
	var before = []
	for sequence in animation.sequences: before.append(sequence.elapsed)
	for i in range(10): await process_frame
	for i in range(before.size()): assert(animation.sequences[i].elapsed == before[i])
	paused = false
	await create_timer(0.2).timeout
	assert(animation.sequences[0].elapsed != before[0])
	print("Hive animation: four sequences, distinct frames, wrap, negative delta and tree pause passed")
	scene.queue_free()
	await process_frame
	quit()
