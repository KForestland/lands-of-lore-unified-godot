extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_development_mode(false)
	var nest = scene.get_node("Nest")
	var chasm = scene.get_node("Chasm")
	var warriors = scene.get_node("Warriors")
	var quests = scene.Save.Shared.Quests
	nest.set_physics_process(false)
	chasm.set_physics_process(false)
	warriors.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.flying = false
	assert(nest.clips[0].size() == 36 and nest.clips[1].size() == 28)
	assert(nest.nest.visible and not nest.actor.visible)
	assert(nest.actor.position == Vector3(-642,-235,-6462))
	for region in nest.data.approaches:
		var center := Vector2.ZERO
		for p in region.polygon: center += Vector2(p[0],p[1])/region.polygon.size()
		assert(nest.inside_approach(Vector3(center.x,region.floor+32,center.y)))
	assert(not nest.inside_approach(Vector3(100000,0,100000)))
	# Actual grounded source-region admission, including control guards.
	var region = nest.data.approaches[4]
	var center := Vector2.ZERO
	for p in region.polygon: center += Vector2(p[0],p[1])/region.polygon.size()
	scene.player.position = Vector3(center.x,region.floor+34,center.y)
	for i in range(60): await physics_frame
	assert(scene.player.is_on_floor())
	paused = true
	assert(not nest.approach())
	paused = false
	scene.flying = true
	assert(not nest.approach())
	scene.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not nest.approach())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	warriors.health = 0
	assert(not nest.approach())
	warriors.health = 30
	assert(nest.approach() and nest.phase == 1)
	assert(not nest.approach())
	scene.set_physics_process(false)
	nest.restore({"phase":1,"elapsed":1.0})
	nest.advance(0.5)
	assert(nest.phase == 1 and nest.elapsed == 1.5)
	nest.advance(0.9)
	assert(nest.phase == 2 and is_zero_approx(nest.elapsed))
	nest.advance(0.8)
	assert(nest.rendered_clip == 1 and nest.rendered_frame == 12)
	var saved: Dictionary = nest.checkpoint().duplicate(true)
	for delta in [-1.0,0.0,NAN,INF]: nest.advance(delta)
	assert(nest.checkpoint() == saved)
	paused = true
	nest.advance(10)
	assert(nest.checkpoint() == saved)
	paused = false
	var path := "user://tests/nest_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	nest.show_actor()
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(nest.checkpoint() == saved and nest.rendered_frame == 12)
	var count: int = nest.activation_count
	nest.advance(2)
	assert(nest.phase == 3 and nest.elapsed == 0 and nest.actor.visible and not nest.nest.visible)
	nest.advance(100)
	assert(nest.activation_count == count+1)
	var transfer: Dictionary = scene.area_handoff()
	transfer.quests.hive_nest.phase = 0
	assert(nest.phase == 3) # deep-copy export
	for bad in [null,{}, {"phase":true,"elapsed":0},{"phase":-1,"elapsed":0},
		{"phase":4,"elapsed":0},{"phase":1.5,"elapsed":0},{"phase":0,"elapsed":true},
		{"phase":0,"elapsed":NAN},{"phase":0,"elapsed":INF},{"phase":0,"elapsed":-1},
		{"phase":0,"elapsed":quests.NEST_LOOP_DURATION},{"phase":2,"elapsed":quests.NEST_RISE_DURATION},
		{"phase":3,"elapsed":0.1}]:
		var before: Dictionary = scene.area_handoff()
		var invalid: Dictionary = before.duplicate(true)
		invalid.quests.hive_nest = bad
		assert(not scene.apply_area_handoff(invalid).is_empty())
		assert(scene.area_handoff() == before)
	# Render the restored film and handoff at the original location for inspection.
	scene.player.position = nest.nest.position+Vector3(0,32,160)
	scene.camera.look_at(nest.nest.position+Vector3(0,38,0),Vector3.UP)
	nest.restore({"phase":2,"elapsed":0.8})
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/home/bob/lol2_out/hive_executioner_review_20260915/handoff_rising.png")
	nest.show_actor()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/home/bob/lol2_out/hive_executioner_review_20260915/handoff_active.png")
	# Chasm bypass from every nest phase; repeat activation is idempotent.
	for phase in range(4):
		nest.restore({"phase":phase,"elapsed":0.0})
		chasm.restore(quests.initial_chasm())
		assert(chasm.activate())
		assert(nest.phase == 3 and nest.actor.visible)
		count = nest.activation_count
		assert(not chasm.activate())
		assert(nest.activation_count == count)
	# Legacy handoff with an already-collapsed chasm immediately shows actor36.
	var legacy: Dictionary = scene.area_handoff()
	legacy.quests.erase("hive_nest")
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(nest.phase == 3)
	legacy.quests.hive_chasm = quests.initial_chasm()
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(nest.phase == 0 and nest.elapsed == 0)
	# New field survives existing jungle save/handoff transport.
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	var handoff: Dictionary = scene.area_handoff()
	handoff.quests.hive_nest = {"phase":2,"elapsed":0.8}
	assert(jungle.apply_area_handoff(handoff).is_empty())
	handoff.quests.hive_nest.elapsed = 0
	assert(jungle.area_handoff().quests.hive_nest.elapsed == 0.8)
	assert(scene.apply_area_handoff(jungle.area_handoff()).is_empty())
	assert(nest.phase == 2 and nest.elapsed == 0.8)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	jungle.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	await process_frame
	print("PASS: Hive nest source admission, clips, pause, save, invalid states, chasm bypass, legacy and jungle handoff")
	quit()
