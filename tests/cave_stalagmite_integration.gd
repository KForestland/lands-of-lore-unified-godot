extends SceneTree
const Aloe = preload("res://scripts/lol2/cave_stalagmite.gd")
var scene: Node
func _initialize() -> void: call_deferred("run")
func press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	scene._unhandled_input(event)
	scene._update_interaction()
func run() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready and scene.stalagmites != null)
	scene.set_physics_process(false)
	scene.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var plant: MeshInstance3D = scene.stalagmites.plants[641]
	var target: Vector3 = plant.to_global(plant.mesh.center_offset)
	# Initial test spawn beside the original entrance plant; interactions use
	# real view/reach/occlusion and the production E-input path.
	scene.player.global_position = plant.global_position+Vector3(0,34,-55)
	scene.camera.look_at(target)
	scene.flying = false
	await physics_frame
	assert(scene.stalagmites.target() == 641)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK)
	var path := "user://tests/stalagmite_%d.json" % Time.get_ticks_usec()
	assert(scene._quicksave(path).is_empty())
	for count in range(1,2):
		press_e()
		assert(scene.stalagmites.collected.size() == count)
		assert(scene.stalagmites.count_for(641) == count)
		var texture: Texture2D = scene.stalagmites.textures[3]
		assert(plant.material_override.get_shader_parameter("indices") == texture)
		for pair in scene.occluder_pairs + scene.light_pairs:
			if pair[0] == plant: assert(pair[1].material_override.get_shader_parameter("indices") == texture)
	press_e()
	assert(scene.stalagmites.collected.size() == 1 and scene.stalagmites.target() == -1)
	assert(scene._quickload(path).is_empty())
	assert(scene.stalagmites.collected.is_empty() and scene.stalagmites.target() == 641)
	press_e()
	assert(scene._quicksave(path).is_empty())
	var open_inventory := InputEventKey.new()
	open_inventory.keycode = KEY_I
	open_inventory.pressed = true
	scene._unhandled_input(open_inventory)
	assert(scene.inventory.item_list.get_item_text(0) == "Stalagmite")
	assert(not scene.inventory.equip_button.disabled)
	scene.inventory.equip_button.pressed.emit()
	assert(scene.equipped_item == scene.stalagmites.collected[0])
	scene.inventory.close()
	await process_frame
	assert(scene._quicksave(path).is_empty())
	var state: Dictionary = scene._save_state()
	assert(scene.set_equipped_item(""))
	assert(scene._quickload(path).is_empty())
	assert(scene.equipped_item == scene.stalagmites.collected[0])
	assert(Aloe.validate_ids(state.stalagmites))
	assert(not Aloe.validate_ids([Aloe.item_id(641,2)]))
	assert(not Aloe.validate_ids([Aloe.item_id(641,1),Aloe.item_id(641,1)]))
	assert(not Aloe.valid_item("cave:prop999:harvest1:Stalagmite"))
	# A real wall between camera and plant must block harvesting.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,100,3)
	shape.shape = box
	wall.add_child(shape)
	scene.add_child(wall)
	wall.global_position = scene.camera.global_position.lerp(target,0.5)
	await physics_frame
	assert(scene.stalagmites.target() == -1)
	press_e()
	assert(scene.stalagmites.collected.size() == 1)
	wall.free()
	DirAccess.remove_absolute(path)
	var carried: Array = scene.stalagmites.collected.duplicate()
	# Same metadata contract used by the actual chamber handoff.
	set_meta("lol2_cave_completion", {"collected": carried, "equipped_item": scene.equipped_item, "chamber_complete": true})
	scene.free()
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	museum.set_physics_process(false)
	assert(museum.carried_collected == carried and museum.equipped_item == carried[0])
	assert("Stalagmite" in museum.interface_hud.character_text())
	assert(museum.open_inventory())
	assert(museum.inventory.item_list.get_item_text(0) == "Stalagmite")
	museum.inventory.close()
	await process_frame
	var museum_path := "user://tests/stalagmite_museum_%d.json" % Time.get_ticks_usec()
	assert(museum.quicksave(museum_path).is_empty())
	var saved = preload("res://scripts/lol2/museum_save.gd").read_save(museum_path)
	assert(saved.error.is_empty() and saved.state.checkpoint.collected == carried)
	var inv := {"collected": carried,"equipped_item":carried[0],"equipped_armor":""}
	assert(preload("res://scripts/lol2/jungle_save.gd").validate_inventory(inv).is_empty())
	DirAccess.remove_absolute(museum_path)
	museum.free()
	print("PASS original Stalagmite: E pickup, one-time grant, indexed/light copies, save rollback, weapon selection, wall occlusion")
	print("PASS Stalagmite carry: Museum handoff/equipment/label, Museum disk save, Jungle inventory validation")
	quit()
