extends "res://scripts/lol2/special_placed_prop_review.gd"

var walkthrough_ready := false
var hud: Label
var dynamic_order: Array = []
var audit_frame := 0
var audit_pose := 0
var audit_start: Transform3D
var walk_check_frame := 0
var walk_check_start := Vector3.ZERO
var light_view: SubViewport
var light_camera: Camera3D
var light_pairs: Array = []
var lighting_enabled := true
var lighting_frame := 0
var light_materials: Array[ShaderMaterial] = []
var glows_enabled := true
var glow_frame := 0
var glow_record := 1108
var dummy_root: Node3D
var dummy_frame := 0

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
	_build_lighting()
	lighting_enabled = not ("--walkthrough-capture" in OS.get_cmdline_user_args() or "--reference-lighting" in OS.get_cmdline_user_args())
	_set_lighting(lighting_enabled)
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
	if not "--glow-capture" in OS.get_cmdline_user_args():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--glow-record="):
				_position_glow_review()
				player.global_position.y += 16.0
	if "--glow-capture" in OS.get_cmdline_user_args():
		_position_glow_review()
		set_physics_process(false)
		set_process_unhandled_input(false)
		hud.visible = false
	if "--dummy-capture" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_process_unhandled_input(false)
		hud.visible = false
	if "--lighting-capture" in OS.get_cmdline_user_args():
		set_physics_process(false)
		set_process_unhandled_input(false)
		hud.visible = false
	if "--controls-check" in OS.get_cmdline_user_args():
		call_deferred("_run_controls_check")

func _resize_index_view() -> void:
	super._resize_index_view()
	if light_view != null: light_view.size = index_view.size
	for view in layer_views: view.size = index_view.size
	for view in composites:
		view.size = index_view.size
		view.get_child(0).size = Vector2(index_view.size)

func _reset() -> void:
	super._reset()
	# Inspection look_at can leave local yaw/roll. Walking owns yaw on
	# the player, and only pitch on the child camera.
	camera.rotation = Vector3(-0.15, 0.0, 0.0)

func _jump_checkpoint(index: int) -> void:
	flying = false
	super._jump_checkpoint(index)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_set_lighting(not lighting_enabled)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		glows_enabled = not glows_enabled
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		dummy_root.visible = not dummy_root.visible
		return
	# Comparison-wall toggle is a diagnostic feature, not part of this view.
	if event is InputEventKey and event.keycode == KEY_T: return
	super._unhandled_input(event)

func _process(_delta: float) -> void:
	if not walkthrough_ready: return
	for instance in placed_instances: instance.visible = props_root.visible
	light_camera.global_transform = camera.global_transform
	for material in light_materials: material.set_shader_parameter("glow_enabled", glows_enabled and props_root.visible)
	for pair in light_pairs: pair[1].visible = pair[0].is_visible_in_tree()
	index_camera.global_transform = camera.global_transform
	for cam in layer_cameras: cam.global_transform = camera.global_transform
	for pair in occluder_pairs:
		pair[1].visible = pair[0].is_visible_in_tree()
	var order: Array = range(placed_props.size())
	var direction := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z)
	order.sort_custom(func(a, b):
		var da := direction.dot(point(placed_props[a].position_native))
		var db := direction.dot(point(placed_props[b].position_native))
		return da < db if not is_equal_approx(da, db) else a < b)
	dynamic_order = order
	for i in range(order.size()):
		composites[i].get_child(0).material.set_shader_parameter("source_indices", layer_views[order[i]].get_texture())
	hud.text = "Draracle Caverns · Walkthrough proof of concept\nWASD + mouse · Shift sprint · Esc release mouse · Click resume\nF fly · Space/Ctrl fly up/down · N/P checkpoints · R reset\nK dummy creatures · B props · C roof · G glow · L lighting: %s · %s · checkpoint %d\nOriginal assets; lighting and some materials remain provisional." % ["Enhanced" if lighting_enabled else "Reference", "Flying" if flying else "Walking", checkpoint + 1]
	if "--dummy-capture" in OS.get_cmdline_user_args():
		_capture_dummies()
	if "--glow-capture" in OS.get_cmdline_user_args():
		_capture_glow()
	if "--lighting-capture" in OS.get_cmdline_user_args():
		_capture_lighting()
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

func _run_controls_check() -> void:
	set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.collision_mask = 0
	var failures := 0
	var cases := 0
	for checkpoint_id in [13, 0]:
		_jump_checkpoint(checkpoint_id)
		for turn in [0.0, 100.0, -200.0]:
			var mouse := InputEventMouseMotion.new()
			mouse.relative = Vector2(turn, 15)
			_unhandled_input(mouse)
			var forward := -camera.global_basis.z
			forward.y = 0
			forward = forward.normalized()
			var right := camera.global_basis.x
			right.y = 0
			right = right.normalized()
			for pair in [[KEY_W, forward], [KEY_S, -forward], [KEY_A, -right], [KEY_D, right]]:
				player.global_position = Vector3(0, 10000, 0)
				player.velocity = Vector3.ZERO
				var event := InputEventKey.new()
				event.keycode = pair[0]
				event.physical_keycode = pair[0]
				event.pressed = true
				Input.parse_input_event(event)
				Input.flush_buffered_events()
				await get_tree().physics_frame
				var before := player.global_position
				_physics_process(1.0 / 60.0)
				var release: InputEventKey = event.duplicate()
				release.pressed = false
				Input.parse_input_event(release)
				Input.flush_buffered_events()
				var moved := player.global_position - before
				moved.y = 0
				var alignment := moved.normalized().dot(pair[1])
				cases += 1
				if alignment < 0.999:
					failures += 1
					print("Direction mismatch key %s: camera alignment %.4f" % [pair[0], alignment])
	# R/reset must also remove an inherited inspection yaw/roll.
	camera.rotation = Vector3(0.2, 1.1, 0.3)
	_reset()
	if absf(camera.rotation.y) > 0.0001 or absf(camera.rotation.z) > 0.0001: failures += 1
	print("WASD camera-relative checks: %d cases, %d failures" % [cases, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _set_lighting(enabled: bool) -> void:
	lighting_enabled = enabled
	resolve_surface.material.set_shader_parameter("enhanced_lighting", enabled)
	light_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED

func _build_lighting() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/prop_review/props.json")).props
	var positions := PackedVector3Array()
	var glow_material_ids: Dictionary = {}
	for i in range(catalog.size()):
		var prop: Dictionary = catalog[i]
		if int(prop.descriptor) == 469:
			positions.append(point(prop.position_native) + native_translation + Vector3(0, float(prop.top) * 0.65, 0))
			var instance: MeshInstance3D = props_root.get_child(i)
			glow_material_ids[instance.material_override.get_instance_id()] = true
	assert(positions.size() == 4)
	var originals: Array = []
	for pair in occluder_pairs: originals.append(pair[0])
	originals.append_array(placed_instances)
	var materials: Dictionary = {}
	for original in originals:
		var source: Material = original.material_override if original.material_override != null else original.mesh.surface_get_material(0)
		var key := source.get_instance_id()
		if not materials.has(key):
			var material: ShaderMaterial = source.duplicate()
			material.set_shader_parameter("mask_capture", false)
			material.set_shader_parameter("lighting_capture", true)
			material.set_shader_parameter("glow_positions", positions)
			material.set_shader_parameter("glowing_prop", glow_material_ids.has(key))
			light_materials.append(material)
			materials[key] = material
		var mesh := MeshInstance3D.new()
		mesh.mesh = original.mesh
		mesh.material_override = materials[key]
		mesh.layers = 64
		add_child(mesh)
		mesh.global_transform = original.global_transform
		light_pairs.append([original, mesh])
	light_view = SubViewport.new()
	light_view.size = index_view.size
	light_view.world_3d = get_world_3d()
	add_child(light_view)
	light_camera = Camera3D.new()
	light_camera.cull_mask = 64
	light_camera.fov = camera.fov
	light_camera.near = camera.near
	light_camera.far = camera.far
	light_camera.environment = Environment.new()
	light_camera.environment.background_mode = Environment.BG_COLOR
	light_camera.environment.background_color = Color(0.24, 0.275, 0.325)
	light_view.add_child(light_camera)
	light_camera.current = true
	resolve_surface.material.set_shader_parameter("light_field", light_view.get_texture())

func _capture_lighting() -> void:
	lighting_frame += 1
	if lighting_frame in [18, 30, 42]:
		await RenderingServer.frame_post_draw
		var directory := "res://captures/lighting_%d" % (checkpoint + 1)
		DirAccess.make_dir_recursive_absolute(directory)
		var name := "enhanced" if lighting_frame == 18 else "reference" if lighting_frame == 30 else "restored"
		get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")
		index_view.get_texture().get_image().save_png(directory + "/indices_" + name + ".png")
		composites.back().get_texture().get_image().save_png(directory + "/final_indices_" + name + ".png")
		if lighting_frame == 18:
			light_view.get_texture().get_image().save_png(directory + "/light.png")
			_set_lighting(false)
		elif lighting_frame == 30: _set_lighting(true)
		else: get_tree().quit()

func _position_glow_review() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--glow-record="): glow_record = int(argument.trim_prefix("--glow-record="))
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/prop_review/props.json")).props
	for prop in catalog:
		if int(prop.record) == glow_record and int(prop.descriptor) == 469:
			var center := point(prop.position_native) + native_translation + Vector3(0, float(prop.top) / 2, 0)
			var location := Vector3.ZERO
			for face in data.faces:
				if int(face.region) == int(prop.region):
					for vertex in face.points: location += point(vertex) * 64.0
					location /= face.points.size()
					break
			location += native_translation
			if Vector2(location.x - center.x, location.z - center.z).length() < 20.0:
				var farthest := location
				for face in data.faces:
					if int(face.region) == int(prop.region):
						for vertex in face.points:
							var candidate := point(vertex) * 64.0 + native_translation
							if candidate.distance_squared_to(center) > farthest.distance_squared_to(center): farthest = candidate
				location = location.lerp(farthest, 0.65)
			location.y = center.y + 12
			player.global_position = location - Vector3(0, 24, 0)
			player.look_at(Vector3(center.x, player.global_position.y, center.z))
			camera.look_at(center)
			return
	push_error("Glow review record must be111,543,1108 or1137")
	get_tree().quit(1)

func _capture_glow() -> void:
	glow_frame += 1
	if glow_frame in [18, 30, 42]:
		await RenderingServer.frame_post_draw
		var directory := "res://captures/glow_%d" % glow_record
		DirAccess.make_dir_recursive_absolute(directory)
		var name := "glow" if glow_frame == 18 else "plain" if glow_frame == 30 else "restored"
		get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")
		composites.back().get_texture().get_image().save_png(directory + "/indices_" + name + ".png")
		light_view.get_texture().get_image().save_png(directory + "/light_" + name + ".png")
		if glow_frame == 18: glows_enabled = false
		elif glow_frame == 30: glows_enabled = true
		else: get_tree().quit()

func _configure_review() -> void:
	super._configure_review()
	dummy_root = Node3D.new()
	stage.add_child(dummy_root)
	var root := "res://assets/lol2/generated/dummy_creatures/"
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(root + "creatures.json"))
	var frames: Dictionary = {}
	var materials: Dictionary = {}
	for frame in catalog.frames:
		var descriptor := int(frame.descriptor)
		frames[descriptor] = frame
		var material := _indexed_material(root + "creature_%d.png" % descriptor)
		material.set_shader_parameter("sprite", true)
		materials[descriptor] = material
	for placement in catalog.placements:
		var center := Vector3.ZERO
		var found := false
		for face in data.faces:
			if int(face.region) == int(placement.region):
				for vertex in face.points: center += point(vertex) * 64.0
				center /= face.points.size()
				if placement.has("vertex"):
					center = center.lerp(point(face.points[int(placement.vertex)]) * 64.0, float(placement.fraction))
				found = true
				break
		assert(found)
		var descriptor := int(placement.descriptor)
		var frame: Dictionary = frames[descriptor]
		var quad := QuadMesh.new()
		quad.size = Vector2(frame.preview_width, frame.preview_height)
		quad.center_offset.y = float(frame.preview_height) * 0.5
		quad.material = materials[descriptor]
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		instance.position = center + native_translation
		instance.layers = 2
		dummy_root.add_child(instance)
	print("Dummy creature preview:2 guards and2 roach-like sprites; provisional scale/positions")

func _capture_dummies() -> void:
	if dummy_frame == 0 and not player.is_on_floor(): return
	dummy_frame += 1
	if dummy_frame in [60, 72, 84]:
		await RenderingServer.frame_post_draw
		set_physics_process(false)
		var directory := "res://captures/dummies_%d" % (checkpoint + 1)
		DirAccess.make_dir_recursive_absolute(directory)
		var name := "shown" if dummy_frame == 60 else "hidden" if dummy_frame == 72 else "restored"
		get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png")
		index_view.get_texture().get_image().save_png(directory + "/indices_" + name + ".png")
		if dummy_frame == 60: dummy_root.visible = false
		elif dummy_frame == 72: dummy_root.visible = true
		else: get_tree().quit()
