extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var chasm = scene.get_node("Chasm")
	chasm.set_physics_process(false)
	var quests = scene.Save.Shared.Quests
	assert(chasm.configured and chasm.floors.size() == 13 and chasm.frames.size() == 73)
	assert(not chasm.activated and chasm.trigger.collision_layer == 4)
	for floor_body in chasm.floors: assert(floor_body.collision_layer == 0)
	var state: Dictionary = scene.area_handoff()
	state.quests.hive_chasm = {"activated":true,"elapsed":0.0}
	assert(scene.apply_area_handoff(state).is_empty())
	scene.set_physics_process(false)
	chasm.advance(1.75)
	var snapshot: Dictionary = chasm.checkpoint().duplicate(true)
	var heights: Array = []
	for body in chasm.floors:
		assert(body.visible and body.collision_layer == 1)
		heights.append(body.position.y)
	assert(chasm.trigger.collision_layer == 0 and chasm.rendered_frame == 26)
	paused = true
	chasm.advance(10)
	assert(chasm.checkpoint() == snapshot)
	paused = false
	for delta in [-1.0,NAN,INF]: chasm.advance(delta)
	assert(chasm.checkpoint() == snapshot)
	var path := "user://tests/chasm_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	chasm.restore(quests.initial_chasm())
	assert(not chasm.activated)
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(chasm.checkpoint() == snapshot)
	for i in heights.size(): assert(chasm.floors[i].position.y == heights[i])
	var baseline: Dictionary = scene.area_handoff().duplicate(true)
	for bad in [null,{}, {"activated":1,"elapsed":0},{"activated":false,"elapsed":1},
		{"activated":true,"elapsed":true},{"activated":true,"elapsed":-1},
		{"activated":true,"elapsed":NAN},{"activated":true,"elapsed":INF},
		{"activated":true,"elapsed":quests.CHASM_DURATION+0.01}]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid.quests.hive_chasm = bad
		invalid.inventory.collected = []
		assert(not scene.apply_area_handoff(invalid).is_empty())
		assert(scene.area_handoff() == baseline)
	var legacy: Dictionary = baseline.duplicate(true)
	legacy.quests.erase("hive_chasm")
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(not chasm.activated)
	assert(scene.apply_area_handoff(baseline).is_empty())
	chasm.advance(100)
	assert(chasm.completed and not chasm.rubble.visible)
	for body in chasm.floors: assert(body.position.y == body.get_meta("target_rise"))
	# Ray checks distinguish restored bridge collision from the old pit beneath it.
	await physics_frame
	await physics_frame
	for i in chasm.data.floors.size():
		var floor_data: Dictionary = chasm.data.floors[i]
		var center := Vector3.ZERO
		for p in floor_data.points: center += Vector3(p[0],p[1],p[2])/4.0
		var ray := PhysicsRayQueryParameters3D.create(Vector3(center.x,-150,center.z),Vector3(center.x,-650,center.z),1,[scene.player.get_rid()])
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty() and is_equal_approx(hit.position.y,float(floor_data.target_height)),"Floor%s expected%s got%s" % [floor_data.region,floor_data.target_height,hit])
	# A saved player standing on the raised bridge must settle on resume, not fall
	# through or inherit the restore's large platform translation as launch velocity.
	var sample: Dictionary = chasm.data.floors[0]
	var center := Vector3.ZERO
	for p in sample.points: center += Vector3(p[0],p[1],p[2])/4.0
	scene.player.position = Vector3(center.x,float(sample.target_height)+33,center.z)
	scene.player.velocity = Vector3.ZERO
	scene.set_physics_process(false)
	for i in range(90):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	assert(scene.player.is_on_floor())
	var saved_position: Vector3 = scene.player.position
	assert(scene.quicksave(path).is_empty())
	chasm.restore(quests.initial_chasm())
	for i in range(2): await physics_frame
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	for i in range(90):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	assert(scene.player.is_on_floor() and scene.player.position.distance_to(saved_position) < 0.2)
	# Deep-copy transport through the jungle adapter preserves the completed crossing.
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	var transfer: Dictionary = scene.area_handoff()
	assert(jungle.apply_area_handoff(transfer).is_empty())
	transfer.quests.hive_chasm.elapsed = 0.0
	assert(jungle.quest_state.hive_chasm.elapsed == quests.CHASM_DURATION)
	assert(scene.apply_area_handoff(jungle.area_handoff()).is_empty() and chasm.completed)
	DirAccess.remove_absolute(path)
	jungle.queue_free()
	scene.queue_free()
	await process_frame
	print("Hive chasm save: partial motion/frame/collision, pause, invalid/no-mutation, legacy default,13 final ray checks and deep-copy jungle transport passed")
	quit()
