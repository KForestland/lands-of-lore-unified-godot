extends Node
const State = preload("res://scripts/lol2/chain_event_preview_state.gd")
const Rule = preload("res://scripts/lol2/chain_short_sword_rule.gd")
var state := State.new()
var rule := Rule.new()
var host: Node3D
var mesh: MeshInstance3D
var textures: Array[Texture2D] = []
var waiting := false
var applied := -1
func setup(walkthrough: Node3D) -> void:
	host = walkthrough
	for resource in [87, 89, 88]:
		for frame in range(27 if resource == 89 else 1):
			var path := "res://assets/lol2/chain/indices_resource_%d_frame_%d.png" % [resource, frame]
			textures.append(ImageTexture.create_from_image(Image.load_from_file(path)))
	mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(38, 60)
	mesh.mesh = quad
	mesh.position = Vector3(1217, -165, -11501) + host.native_translation
	mesh.material_override = host._indexed_material("res://assets/lol2/chain/indices_resource_87_frame_0.png")
	mesh.material_override.set_shader_parameter("sprite", true)
	mesh.layers = 2
	host.add_child(mesh)
	host._copy_occluders(mesh)
func can_strike() -> bool:
	if state.started or host.flying:
		return false
	var offset: Vector3 = mesh.global_position - host.camera.global_position
	if offset.length() < 0.01 or offset.length() > 96.0:
		return false
	if (-host.camera.global_basis.z).dot(offset.normalized()) < 0.97:
		return false
	var query := PhysicsRayQueryParameters3D.create(host.camera.global_position, mesh.global_position, 1, [host.player.get_rid()])
	query.hit_from_inside = true
	return host.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func strike() -> bool:
	if not can_strike() or rule.strike() != Rule.BREAK_COMMAND:
		return false
	return state.activate()
func reset() -> void:
	state.reset()
	rule.reset()

func saved_state() -> Dictionary:
	var doors: Array = []
	for door in host.indexed_doors: doors.append(door.opening_percent)
	return {"started": state.started, "elapsed": minf(state.elapsed, State.REQUEST_DELAY+State.OPEN_SECONDS), "doors": doors}

static func validate_save(value: Variant) -> bool:
	if not value is Dictionary or not value.get("started") is bool: return false
	var elapsed = value.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0 or elapsed > State.REQUEST_DELAY+State.OPEN_SECONDS: return false
	if not value.started and elapsed != 0: return false
	if not value.get("doors") is Array or value.doors.size() != 2: return false
	var expected := State.new()
	if value.started: expected.activate(); expected.advance(float(elapsed))
	for opening in value.doors:
		if not (opening is int or opening is float) or not is_finite(float(opening)) or opening != floorf(float(opening)) or opening < 0 or opening > expected.opening: return false
	return true

func restore_save(value: Dictionary) -> void:
	assert(validate_save(value))
	reset()
	if value.started:
		rule.strike()
		state.activate()
		state.advance(float(value.elapsed))
	for i in range(host.indexed_doors.size()): host.indexed_doors[i].set_opening(int(value.doors[i]))
	applied = -1
	_sync_frame()
	waiting = host.indexed_doors.any(func(door): return door.opening_percent < state.opening)
func status_text() -> String:
	if waiting:
		return "Stand clear so the doors can move."
	if not state.started:
		return "Strike the chain to release the doors."
	if state.selector != 2:
		return "The chain is breaking…"
	for door in host.indexed_doors:
		if door.opening_percent < 100:
			return "The doors are opening…"
	return "The doors are open."
func tick(delta: float) -> void:
	state.advance(delta)
	_sync_frame()
	waiting = false
	for door in host.indexed_doors:
		if not door.get_child(4).move_toward(state.opening, host.player):
			waiting = true

func _sync_frame() -> void:
	var frame := 0 if state.selector == 0 else 28 if state.selector == 2 else 1 + state.frame
	if frame != applied:
		mesh.material_override.set_shader_parameter("indices", textures[frame])
		for pair in host.occluder_pairs + host.light_pairs:
			if pair[0] == mesh:
				pair[1].material_override.set_shader_parameter("indices", textures[frame])
		applied = frame
