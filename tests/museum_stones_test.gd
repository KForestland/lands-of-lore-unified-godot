extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func aim(scene: Node3D, index: int) -> void:
	var sprite: Sprite3D = scene.champion_stones.sprites[index]
	scene.player.position = sprite.position + Vector3(90 if index == 0 else -23,-18,0)
	scene.camera.look_at(sprite.position + Vector3(0,3.5,0))
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	assert(scene.champion_stones.sprites.size() == 2)
	aim(scene,0)
	await physics_frame
	await physics_frame
	assert(scene.can_take_stone(0))
	if "--capture-stones" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_champion_stones.png")
	assert(scene.take_stone(0) and not scene.take_stone(0))
	assert(not scene.champion_stones.sprites[0].visible and scene.champion_stones.sprites[1].visible)
	var path := "user://tests/stones_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	aim(scene,1)
	await physics_frame
	assert(scene.can_take_stone(1))
	assert(scene.take_stone(1) and not scene.take_stone(1))
	assert(scene.carried_collected.size() == 2)
	assert(scene.open_inventory())
	assert(scene.inventory.item_list.item_count == 2)
	for index in range(2):
		assert(scene.inventory.item_list.get_item_text(index) == "Champion Stone")
		assert(scene.inventory.item_list.get_item_metadata(index) == scene.Stones.IDS[index])
		scene.inventory.select_item(index)
		assert(scene.inventory.equip_button.disabled and scene.inventory.detail_icon.texture != null)
	scene.inventory.close()
	await process_frame
	await process_frame
	assert(scene.quickload(path).is_empty())
	assert(scene.carried_collected == [scene.Stones.IDS[0]])
	assert(not scene.champion_stones.sprites[0].visible and scene.champion_stones.sprites[1].visible)
	aim(scene,1)
	await physics_frame
	assert(scene.take_stone(1))
	scene.free()
	scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	assert(scene.carried_collected.size() == 2)
	assert(not scene.champion_stones.sprites[0].visible and not scene.champion_stones.sprites[1].visible)
	assert(not scene.can_take_stone(-1) and not scene.can_take_stone(2))
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	DirAccess.remove_absolute(path)
	print("Champion Stones passed: independent pickup, duplicate protection, two inventory entries, partial-save restore, revisit")
	quit()
