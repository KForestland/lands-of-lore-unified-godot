extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	scene.player.position = Vector3(-4222, 32, -1050)
	scene.camera.look_at(scene.sword_transfer.TABLE_SWORD)
	await physics_frame
	assert(not scene.take_sword())
	scene.sword_transfer.restart()
	scene.sword_transfer.advance(4)
	assert(scene.can_take_sword())
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,120,4)
	collider.shape = box
	wall.add_child(collider)
	wall.position = Vector3(-4222,60,-1070)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	assert(not scene.can_take_sword())
	wall.free()
	await physics_frame
	scene.camera.rotate_y(PI)
	assert(not scene.can_take_sword())
	scene.camera.look_at(scene.sword_transfer.TABLE_SWORD)
	scene.player.position.z += 150
	assert(not scene.can_take_sword())
	scene.player.position.z -= 150
	assert(scene.take_sword())
	assert(not scene.take_sword() and not scene.sword_transfer.table_sword.visible)
	assert(scene.carried_collected.count(scene.SWORD_ITEM_ID) == 1)
	scene.sword_transfer.advance(10)
	assert(not scene.sword_transfer.table_sword.visible)
	scene.free()
	scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	assert(scene.sword_transfer.collected and not scene.sword_transfer.table_sword.visible)
	assert(scene.carried_collected.count(scene.SWORD_ITEM_ID) == 1)
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Sword pickup passed: inactive, range, aim, wall occlusion, single collection and revisit")
	quit()
