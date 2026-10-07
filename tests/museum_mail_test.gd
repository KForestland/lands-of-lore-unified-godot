extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	scene.player.position = Vector3(-4150,32,-1164)
	var target: Vector3 = scene.mail_shirt.position + Vector3(0,6,0)
	scene.camera.look_at(target)
	await physics_frame
	await physics_frame
	assert(scene.can_take_mail())
	scene.camera.rotate_y(PI)
	assert(not scene.can_take_mail())
	scene.camera.look_at(target)
	scene.player.position.x += 150
	assert(not scene.can_take_mail())
	scene.player.position.x -= 150
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4,120,100)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(-4180,60,-1164)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	assert(not scene.can_take_mail())
	wall.free()
	await physics_frame
	if "--capture-mail" in OS.get_cmdline_user_args():
		scene.sword_transfer.restart()
		scene.sword_transfer.advance(4)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_mail_shirt.png")
	assert(scene.take_mail())
	assert(not scene.take_mail() and not scene.mail_shirt.visible)
	assert(scene.carried_collected.count(scene.MAIL_ITEM_ID) == 1)
	assert(scene.open_inventory())
	assert(scene.inventory.item_list.get_item_text(0) == "Mail Shirt")
	assert(scene.inventory.detail_icon.texture != null and not scene.inventory.equip_button.disabled)
	scene.inventory.close()
	await process_frame
	await process_frame
	var path := "user://tests/mail_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	scene.carried_collected.clear()
	scene.mail_shirt.show()
	assert(scene.quickload(path).is_empty())
	assert(not scene.mail_shirt.visible and scene.MAIL_ITEM_ID in scene.carried_collected)
	scene.free()
	scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	assert(not scene.mail_shirt.visible and scene.MAIL_ITEM_ID in scene.carried_collected)
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	DirAccess.remove_absolute(path)
	print("Mail pickup passed: aim/range/occlusion, once only, named inventory/icon, armor selection available, disk and revisit persistence")
	quit()
