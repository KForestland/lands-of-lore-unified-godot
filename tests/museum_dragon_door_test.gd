extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	var door = scene.dragon_door
	door.set_physics_process(false)
	scene.player.position = Vector3(3048,32,-790)
	scene.camera.look_at(door.global_position+Vector3(0,35,0))
	await physics_frame
	await physics_frame
	assert(scene.player.test_move(scene.player.global_transform,Vector3(0,0,-60)))
	assert(door.position == Vector3(3048,0,-834))
	assert(scene.can_open_dragon_door())
	scene.interface_hud.set_cursor(true)
	assert(not scene.open_dragon_door())
	scene.interface_hud.set_cursor(false)
	assert(scene.open_dragon_door())
	assert(not scene.open_dragon_door())
	door._physics_process(0.5)
	var path := "user://tests/dragon_door_%d.json" % OS.get_process_id()
	assert(scene.quicksave(path).is_empty())
	door.restore_checkpoint({})
	assert(scene.quickload(path).is_empty())
	assert(door.opened and door.progress == 0.5)
	door._physics_process(0.5)
	await physics_frame
	assert(not scene.player.test_move(scene.player.global_transform,Vector3(0,0,-60)))
	DirAccess.remove_absolute(path)
	print("Dragon door passed: blocked/clear capsule sweep, reachable interaction, menu/repeat guard and mid-motion save/load")
	quit()
