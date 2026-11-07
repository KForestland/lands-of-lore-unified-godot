extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for group in [10414,10510]:
		var pillar = preload("res://scripts/lol2/hive_pillar.gd").new()
		root.add_child(pillar)
		pillar.set_process(false)
		assert(pillar.position == Vector3(-1173,-242,-8677))
		assert(pillar.mesh.size == Vector2(49,128))
		assert(pillar.material_override.uv1_scale.x == -1)
		assert(not pillar.apply_source_group(10596)) # Executioner group is unrelated.
		paused = true
		assert(not pillar.apply_source_group(group))
		paused = false
		assert(not pillar.apply_actor_event(35,10))
		assert(not pillar.apply_actor_event(36,10))
		var actor_index := 32 if group == 10414 else 34
		assert(not pillar.apply_actor_event(actor_index,9))
		assert(not pillar.apply_actor_event(actor_index,11))
		assert(pillar.apply_actor_event(actor_index,10))
		assert(not pillar.apply_source_group(group))
		pillar.advance(-1)
		pillar.advance(NAN)
		assert(pillar.position == pillar.origin)
		pillar.advance(0.5)
		assert(pillar.position.is_equal_approx(Vector3(-1207.5,-242,-8689.5)))
		paused = true
		pillar.advance(10)
		assert(pillar.elapsed == 0.5)
		paused = false
		pillar.advance(10)
		assert(pillar.opened and not pillar.moving)
		assert(pillar.position == Vector3(-1242,-242,-8702))
		assert(not pillar.apply_source_group(group))
		pillar.queue_free()
		await process_frame
	print("Hive pillar: source dimensions, mirror, both movement groups, unrelated group rejection, pause and endpoints passed")
	quit()
