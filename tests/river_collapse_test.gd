extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(300):
		await process_frame
		if is_instance_valid(scene.river_deck): break
	for i in range(5): await physics_frame
	var deck = scene.river_deck
	assert(deck.sections.size() == 6)
	assert(not deck.begin_collapse(55))
	assert(not deck.cut_chain(96), "Sound-only support must not release a deck")
	assert(not deck.cut_chain(93), "First cut retains support")
	assert(deck.sections[58].body.collision_layer == 1)
	assert(not deck.cut_chain(93), "Duplicate cut ignored")
	assert(deck.cut_chain(94), "Second distinct cut releases its section")
	assert(not deck.cut_chain(95), "No repeated release")
	assert(not deck.begin_collapse(58))
	assert(deck.sections[58].body.collision_layer == 0)
	for i in range(10): await physics_frame
	var position: Vector3 = deck.sections[58].mesh.position
	assert(position.y < deck.sections[58].start.y)
	paused = true
	await create_timer(0.2).timeout
	assert(deck.sections[58].mesh.position == position)
	paused = false
	for i in range(60): await physics_frame
	assert(not deck.sections[58].mesh.visible)
	for pair in scene.occluder_pairs + scene.light_pairs:
		if pair[0] == deck.sections[58].mesh:
			assert(not pair[1].visible)
	for id in [56,57,59,60,61]:
		assert(deck.sections[id].body.collision_layer == 1)
		assert(deck.sections[id].mesh.visible)
		assert(deck.sections[id].mesh.position == deck.sections[id].start)
	print("River collapse passed: two distinct chain cuts, sound-only exclusion, one section, duplicate guard, support removal, pause, synchronized visibility and intact neighbors")
	scene.free()
	quit()
