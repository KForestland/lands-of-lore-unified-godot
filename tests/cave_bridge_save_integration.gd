extends SceneTree
const Bridge = preload("res://scripts/lol2/cave_bridge_save.gd")
var scene: Node
var path := "user://tests/bridge_integration_%d.json" % Time.get_ticks_usec()
func _initialize() -> void: call_deferred("run")
func open_cave() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await process_frame
		if scene.river_chains != null and scene.bridge_warning != null: break
	assert(scene.river_chains != null and scene.bridge_warning != null)
	scene.set_physics_process(false)
	scene.river_deck.set_physics_process(false)
	scene.river_chains.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene._jump_checkpoint(13)
func run() -> void:
	assert("--chain-approach" in OS.get_cmdline_user_args())
	await open_cave()
	var intact := Bridge.capture(scene.river_deck, scene.river_chains, scene.bridge_warning)
	for id in [85, 86, 89]:
		scene.river_chains.chains[id].elapsed = 0.4
		scene.river_deck.cut_chain(id)
	scene.river_deck._physics_process(0.35)
	scene.bridge_warning.played = true
	scene.indexed_chain.rule.strike()
	scene.indexed_chain.state.activate()
	scene.indexed_chain.state.advance(3.25)
	# Preserve a door held behind its requested pose by an obstruction.
	scene.indexed_doors[0].set_opening(25)
	scene.indexed_doors[1].set_opening(50)
	scene._jump_checkpoint(scene.fixtures[0].checkpoints.size())
	assert(scene.checkpoint == scene.fixtures[0].checkpoints.size())
	var expected: Dictionary = scene._save_state()
	assert(scene._quicksave(path).is_empty())
	Bridge.restore(intact, scene.river_deck, scene.river_chains, scene.bridge_warning)
	assert(scene._quickload(path).is_empty())
	assert(scene._save_state() == expected)
	scene.free()
	await process_frame
	await open_cave()
	assert(scene._quickload(path).is_empty())
	assert(scene._save_state() == expected)
	assert(scene.river_deck.sections[56].body.collision_layer == 0)
	assert(scene.river_deck.sections[57].body.collision_layer == 1)
	assert(scene.indexed_doors[0].opening_percent == 25 and scene.indexed_doors[1].opening_percent == 50)
	assert(scene.indexed_chain.waiting and scene.indexed_chain.state.door_dispatch_count == 1)
	assert(scene.indexed_chain.rule.script_state == 1)
	var bad := expected.duplicate(true)
	bad.bridge.sections[0] = -1
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	assert(not scene._quickload(path).is_empty())
	assert(scene._save_state() == expected)
	DirAccess.remove_absolute(path)
	scene.free()
	print("PASS cave world integration: bridge, chain-approach checkpoint, obstructed door poses, quicksave/load, new scene, invalid save atomicity")
	quit()
