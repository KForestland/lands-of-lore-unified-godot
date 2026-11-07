extends "res://scripts/lol2/recovered_door_cave_review.gd"
const ChainState = preload("res://scripts/lol2/chain_event_preview_state.gd")
const DoorCollision = preload("res://scripts/lol2/recovered_door_collision.gd")
const ShortSwordRule = preload("res://scripts/lol2/chain_short_sword_rule.gd")
var chain_state := ChainState.new()
var short_sword_rule := ShortSwordRule.new()
var chain_sprite: Sprite3D
var route_prop: Sprite3D
var chain_textures: Array[Texture2D] = []
var chain_status: Label
var applied_texture := -1
const INTERACTION_REACH := 1.5
const AIM_DOT := 0.97
const WalkPlayer = preload("res://scripts/lol2/chain_walk_player.gd")
var walk_player: CharacterBody3D
var walk_button: Button
var interaction_notice: Label

func _ready() -> void:
	super._ready()
	door_controls.hide()
	selection_label.text = "Original chain and doors — orbit to inspect, or choose Walk near chain.\nDoor collision follows opening; Candidate interior spans collide; prop collision remains incomplete."
	for door in recovered_doors:
		var body := DoorCollision.new()
		door.add_child(body)
		body.bind(door)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/chain/chain.json"))
	chain_textures.append(load("res://assets/lol2/chain/resource_87_frame_0.png"))
	for frame in range(27):
		chain_textures.append(load("res://assets/lol2/chain/resource_89_frame_%d.png" % frame))
	chain_textures.append(load("res://assets/lol2/chain/resource_88_frame_0.png"))
	chain_sprite = Sprite3D.new()
	chain_sprite.texture = chain_textures[0]
	chain_sprite.pixel_size = 1.0 / 64.0
	chain_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	chain_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	chain_sprite.shaded = false
	var p: Array = data.position
	chain_sprite.position = Vector3(p[0], p[1], p[2])
	# Source region-height selection is verified; billboard remains provisional.
	var bounds: Dictionary = data.states[0]
	chain_sprite.scale = Vector3((bounds.right - bounds.left) / chain_sprite.texture.get_width(), (bounds.top - bounds.bottom) / chain_sprite.texture.get_height(), 1)
	chain_sprite.position += Vector3((bounds.left + bounds.right) / 128.0, (bounds.top + bounds.bottom) / 128.0, 0)
	add_child(chain_sprite)
	_build_route_prop()
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(720, 24)
	box.custom_minimum_size.x = 450
	ui.add_child(box)
	chain_status = Label.new()
	box.add_child(chain_status)
	var activate := Button.new()
	activate.text = "Break chain (preview)"
	activate.pressed.connect(func() -> void: chain_state.activate(); _sync_chain())
	box.add_child(activate)
	var reset := Button.new()
	reset.text = "Reset chain and doors"
	reset.pressed.connect(func() -> void: _reset_chain())
	box.add_child(reset)
	var note := Label.new()
	note.text = "Original artwork and door targets.\nPreview timing; request 592 completion is simulated.\nE: Short Sword strike when near and aimed.\nRecovered hit rule; preview reach and timing.\nMoving door collision active; saves remain unconnected."
	box.add_child(note)
	_build_interaction_obstacles()
	interaction_notice = Label.new()
	box.add_child(interaction_notice)
	var focus := Button.new()
	focus.text = "Inspect chain"
	focus.pressed.connect(func() -> void:
		center = chain_sprite.position
		radius = 1.2
		pitch = 0.1
		_update_camera())
	box.add_child(focus)
	walk_player = WalkPlayer.new()
	add_child(walk_player)
	walk_button = Button.new()
	walk_button.text = "Walk near chain"
	walk_button.pressed.connect(_start_walk)
	box.add_child(walk_button)
	_sync_chain()
	if "--chain-review-check" in OS.get_cmdline_user_args():
		assert(_strike_chain())
		assert(short_sword_rule.remaining == 1)
		assert(not _strike_chain())
		for i in range(300):
			chain_state.advance(1.0 / 60.0)
			_sync_chain()
		assert(chain_state.selector == 2 and chain_state.door_dispatch_count == 1)
		for door in recovered_doors:
			assert(door.opening_percent == 100)
		_reset_chain()
		assert(short_sword_rule.remaining == 2 and short_sword_rule.script_state == 0)
		for door in recovered_doors:
			assert(door.opening_percent == 0)
		assert(chain_sprite.texture == chain_textures[0])
		print("Chain cave review: break, duplicate guard, settled frame, both doors open, reset passed")
		get_tree().quit()

func _process(delta: float) -> void:
	super._process(delta)
	if chain_sprite == null:
		return
	chain_state.advance(delta)
	_sync_chain()
	interaction_notice.text = "E — strike with Short Sword" if _can_interact() else "Aim at the chain within reach to interact."

func _sync_chain() -> void:
	var texture_index := 0
	if chain_state.selector == 1:
		texture_index = chain_state.frame + 1
	elif chain_state.selector == 2:
		texture_index = 28
	if texture_index != applied_texture:
		chain_sprite.texture = chain_textures[texture_index]
		applied_texture = texture_index
	var blocked := false
	var openings: Array[String] = []
	for door in recovered_doors:
		var body = door.get_child(4)
		if not body.move_toward(chain_state.opening, walk_player if walk_player != null and walk_player.active else null):
			blocked = true
		openings.append("%d%%" % door.opening_percent)
	chain_status.text = "Chain: %s · doors: %s%s" % [["intact", "breaking", "broken"][chain_state.selector], " / ".join(openings), " (waiting for player)" if blocked else ""]

func _strike_chain() -> bool:
	if chain_state.started:
		return false
	if short_sword_rule.strike() != ShortSwordRule.BREAK_COMMAND:
		return false
	chain_state.activate()
	_sync_chain()
	return true

func _reset_chain() -> void:
	chain_state.reset()
	short_sword_rule.reset()
	_sync_chain()

func _can_interact() -> bool:
	if chain_state.started or chain_sprite == null:
		return false
	var offset := chain_sprite.global_position - camera.global_position
	if offset.length() < 0.01 or offset.length() > INTERACTION_REACH:
		return false
	if (-camera.global_basis.z).dot(offset.normalized()) < AIM_DOT:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, chain_sprite.global_position, 1)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if walk_player != null and walk_player.active:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			walk_player.rotate_y(-event.relative.x * 0.002)
			walk_player.view_pitch = clampf(walk_player.view_pitch - event.relative.y * 0.002, -1.3, 1.3)
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			_stop_walk()
			get_viewport().set_input_as_handled()
			return
	else:
		super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if _can_interact():
			_strike_chain()
		get_viewport().set_input_as_handled()

func _update_camera() -> void:
	if walk_player != null and walk_player.active:
		camera.global_position = walk_player.global_position + Vector3.UP * WalkPlayer.EYE_HEIGHT
		camera.global_rotation = Vector3(walk_player.view_pitch, walk_player.rotation.y, 0)
	else:
		super._update_camera()

func _start_walk() -> void:
	# Find a floor near the chain; no teleport occurs if no suitable clearance exists.
	var space := get_world_3d().direct_space_state
	for offset in [Vector3(0, 0, 0.8), Vector3(0.8, 0, 0), Vector3(0, 0, -0.8), Vector3(-0.8, 0, 0)]:
		var probe: Vector3 = chain_sprite.global_position + offset
		var ray := PhysicsRayQueryParameters3D.create(probe, probe - Vector3.UP * 2.0, 1)
		var floor_hit := space.intersect_ray(ray)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.6:
			continue
		var feet: Vector3 = floor_hit.position + Vector3.UP * 0.015
		var shape_query := PhysicsShapeQueryParameters3D.new()
		shape_query.shape = walk_player.get_child(0).shape
		shape_query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.375)
		shape_query.collision_mask = 1
		if not space.intersect_shape(shape_query).is_empty():
			continue
		walk_player.global_position = feet
		walk_player.velocity = Vector3.ZERO
		walk_player.look_at(Vector3(chain_sprite.global_position.x, feet.y, chain_sprite.global_position.z))
		walk_player.view_pitch = 0.0
		walk_player.active = true
		walk_button.text = "Walking: WASD · mouse look · E strike · Esc orbit"
		selection_label.text = "Walking chain review — floor, candidate interior spans and doors collide; prop collision incomplete."
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_update_camera()
		return
	walk_button.text = "No clear floor found near chain"

func _stop_walk() -> void:
	walk_player.active = false
	walk_player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	walk_button.text = "Walk near chain"
	center = chain_sprite.global_position
	radius = 1.2
	pitch = 0.1
	_update_camera()

func _build_interaction_obstacles() -> void:
	# Review geometry supports walking and line of sight. Interior spans remain
	# geometric candidates, not verified native wall/collision semantics.
	shell_nodes["interior"].visible = true
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "floors.json"))
	var triangles := PackedVector3Array()
	var faces: Array = source.faces.duplicate()
	for face in source.shell:
		if face.kind in ["boundary", "ceiling", "interior"]:
			faces.append(face)
	for face in faces:
		for i in [0, 1, 2, 0, 2, 3]:
			var p: Array = face.points[i]
			triangles.append(Vector3(p[0], p[1], p[2]))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(triangles)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(collision)
	add_child(body)

func _build_route_prop() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/prop_review/props.json"))
	for prop in catalog.props:
		if int(prop.record) != 1056:
			continue
		assert(int(prop.template) == 21 and int(prop.descriptor) == 417)
		route_prop = Sprite3D.new()
		route_prop.name = "SourceProp1056"
		route_prop.set_meta("original_record", 1056)
		route_prop.texture = load("res://assets/lol2/generated/prop_review/prop_417.png")
		route_prop.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		route_prop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		route_prop.shaded = false
		route_prop.pixel_size = 1.0 / 64.0
		route_prop.scale = Vector3((prop.right - prop.left) / route_prop.texture.get_width(), (prop.top - prop.bottom) / route_prop.texture.get_height(), 1)
		var p: Array = prop.position_native
		route_prop.position = Vector3(p[0], p[1], p[2]) / 64.0
		route_prop.position += Vector3((prop.left + prop.right) / 128.0, (prop.top + prop.bottom) / 128.0, 0)
		assert(int(prop.frame_flags) == 0, "This local prop requires no frame mirroring")
		add_child(route_prop)
		return
	assert(false, "Required source prop1056 missing from catalogue")
