extends "res://scripts/lol2/special_placed_prop_review.gd"

var walkthrough_ready := false
var hud: Label
var dynamic_order: Array = []
var audit_frame := 0
var audit_pose := 0
var audit_start: Transform3D
var walk_check_frame := 0
var walk_check_start := Vector3.ZERO

func _ready() -> void:
	await super._ready()
	for view in raw_views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera.cull_mask = 0 # Only indexed viewports draw the world.
	get_window().title = "Lands of Lore II — Cavern walkthrough proof of concept"
	var ui := CanvasLayer.new()
	ui.layer = 21
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(14, 12)
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(hud)
	walkthrough_ready = true
	if "--walkthrough-capture" in OS.get_cmdline_user_args():
		audit_start = camera.global_transform
		hud.visible = false
	else:
		var initial_checkpoint := 13
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--checkpoint="): initial_checkpoint = int(argument.trim_prefix("--checkpoint=")) - 1
		_jump_checkpoint(initial_checkpoint)
		set_physics_process(true)
		set_process_unhandled_input(true)
	_resize_index_view()

func _resize_index_view() -> void:
	super._resize_index_view()
	for view in layer_views: view.size = index_view.size
	for view in composites:
		view.size = index_view.size
		view.get_child(0).size = Vector2(index_view.size)

func _jump_checkpoint(index: int) -> void:
	flying = false
	super._jump_checkpoint(index)

func _unhandled_input(event: InputEvent) -> void:
	# Comparison-wall toggle is a diagnostic feature, not part of this view.
	if event is InputEventKey and event.keycode == KEY_T: return
	super._unhandled_input(event)

func _process(_delta: float) -> void:
	if not walkthrough_ready: return
	index_camera.global_transform = camera.global_transform
	for cam in layer_cameras: cam.global_transform = camera.global_transform
	for pair in occluder_pairs:
		pair[1].visible = pair[0].is_visible_in_tree()
	for instance in placed_instances: instance.visible = props_root.visible
	var order: Array = range(placed_props.size())
	var direction := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z)
	order.sort_custom(func(a, b):
		var da := direction.dot(point(placed_props[a].position_native))
		var db := direction.dot(point(placed_props[b].position_native))
		return da < db if not is_equal_approx(da, db) else a < b)
	dynamic_order = order
	for i in range(order.size()):
		composites[i].get_child(0).material.set_shader_parameter("source_indices", layer_views[order[i]].get_texture())
	hud.text = "Draracle Caverns · Walkthrough proof of concept\nWASD + mouse · Shift sprint · Esc release mouse · Click resume\nF fly · Space/Ctrl fly up/down · N/P checkpoints · R reset\nB props · C roof · %s · checkpoint %d\nOriginal assets; lighting and some materials remain provisional." % ["Flying" if flying else "Walking", checkpoint + 1]
	if "--walkthrough-walk-check" in OS.get_cmdline_user_args():
		_walk_check()
	if "--walkthrough-capture" in OS.get_cmdline_user_args():
		audit_frame += 1
		if audit_frame % 12 == 0:
			await RenderingServer.frame_post_draw
			var directory := "res://captures/walkthrough/pose%d" % audit_pose
			DirAccess.make_dir_recursive_absolute(directory)
			index_view.get_texture().get_image().save_png(directory + "/background.png")
			var records: Array = []
			for i in range(order.size()):
				layer_views[order[i]].get_texture().get_image().save_png(directory + "/source%d.png" % i)
				composites[i].get_texture().get_image().save_png(directory + "/composite%d.png" % i)
				records.append(placed_props[order[i]].record)
			get_viewport().get_texture().get_image().save_png(directory + "/resolved.png")
			var file := FileAccess.open(directory + "/view.json", FileAccess.WRITE)
			file.store_string(JSON.stringify({"order": records, "camera": str(camera.global_transform), "props_visible": props_root.visible, "roof_visible": roof.visible, "cameras_synchronized": layer_cameras.all(func(cam): return cam.global_transform.is_equal_approx(camera.global_transform))}, "  "))
			audit_pose += 1
			if audit_pose == 4:
				get_tree().quit()
			else:
				if audit_pose == 1: get_window().size = Vector2i(800, 450)
				props_root.visible = audit_pose != 2
				roof.visible = audit_pose != 3
				camera.global_transform = audit_start
				camera.global_position += Vector3(audit_pose * 0.7, 0, audit_pose * 0.4)
				camera.rotate_y([0.0, 0.4, 1.2, 3.14][audit_pose])

func _walk_check() -> void:
	walk_check_frame += 1
	if walk_check_frame in [30, 90]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_W
		event.keycode = KEY_W
		event.pressed = walk_check_frame == 30
		if event.pressed:
			walk_check_start = player.global_position
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.parse_input_event(event)
	if walk_check_frame == 110:
		var displacement := Vector2(player.global_position.x - walk_check_start.x, player.global_position.z - walk_check_start.z).length()
		print("Walkthrough input check: moved %.2f units; resets %d; grounded %s" % [displacement, resets, player.is_on_floor()])
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures")
		get_viewport().get_texture().get_image().save_png("res://captures/walkthrough_ready.png")
		get_tree().quit(0 if displacement > 1.0 and resets == 0 and player.is_on_floor() else 1)
