extends SceneTree
var starts := 0
var finishes := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	var actor = scene.get_node("ConversationReview")
	actor.set_process(false)
	actor.conversation_started.connect(func(): starts += 1)
	actor.conversation_finished.connect(func(): finishes += 1)
	assert(not actor.can_begin()) # Arrival is far from the conversation.
	assert(not actor.begin())
	scene.player.position = Vector3(-1218,-203,-8725)
	scene.flying = true
	actor.check_room_contact()
	assert(not actor.room_entered)
	scene.flying = false
	paused = true
	actor.check_room_contact()
	assert(not actor.room_entered)
	paused = false
	scene.player.position.y = 0
	actor.check_room_contact()
	assert(not actor.room_entered)
	scene.player.position.y = -203
	actor.check_room_contact()
	assert(actor.room_entered)
	scene.player.position = Vector3(-1174,-203,-8843)
	scene.camera.look_at(actor.global_position+Vector3(0,64,0))
	for i in range(2): await physics_frame
	assert(actor.can_begin())
	paused = true
	assert(not actor.can_begin())
	assert(not actor.begin())
	paused = false
	assert(actor.begin() and not actor.begin())
	assert(starts == 1 and actor.shared_flags[38] == 1)
	assert(not scene.is_physics_processing() and actor.frame == 0)
	for section in [0,2,3,4]:
		var row = actor.data.sections[section]
		assert(actor.frame == int(row.first))
		var duration = float(row.last-row.first+1)/15.0 - actor.elapsed
		actor.advance(duration-0.01)
		assert(actor.frame == int(row.last) and finishes == 0)
		var before = actor.elapsed
		paused = true
		actor.advance(10)
		assert(actor.elapsed == before)
		paused = false
		actor.advance(0.011)
	assert(actor.completed and actor.frame == 912 and finishes == 1)
	assert(scene.is_physics_processing())
	actor.advance(1000)
	assert(finishes == 1 and not actor.begin())
	if "--capture-conversation" in OS.get_cmdline_user_args():
		scene.set_physics_process(false)
		scene.player.position = Vector3(-1174,-203,-8843)
		scene.camera.look_at(actor.global_position+Vector3(0,64,0))
		actor._set_frame(30)
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/hive_geometry_20260914/conversation_review.png")
	print("Hive conversation: section order, first/last frames, start flag, pause, completion and movement restoration passed")
	scene.queue_free()
	await process_frame
	quit()
