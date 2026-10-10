extends "res://scripts/lol2/cave_walkthrough.gd"

const Encounter = preload("res://scripts/lol2/cave_encounter_state.gd")
const ActorAnimation = preload("res://scripts/lol2/cave_actor_animation.gd")
const ENEMY_SPEED := 42.0
const PLAYER_REACH := 96.0
var encounter := Encounter.new()
var animation := ActorAnimation.new()
var animation_materials: Array[ShaderMaterial] = []
var applied_frame := -1
var applied_view := -1
var applied_action := -1
var enemy_facing := Vector2.ZERO
var enemy: CharacterBody3D
var enemy_mesh: MeshInstance3D
var enemy_copies: Array[MeshInstance3D] = []
var player_spawn := Vector3.ZERO
var enemy_spawn := Vector3.ZERO
var exit_position := Vector3.ZERO
var attack_requested := false
var encounter_ready := false
var exit_label: Label

func _ready() -> void:
	source_combat_enabled = false
	full_route_enabled = false
	await super._ready()
	if not walkthrough_ready:
		return
	# Reuse the reviewed roach pose. Actor position and behaviour are prototype.
	for child in dummy_root.get_children():
		if child.get_meta("dummy_id", "") == "roach_a":
			enemy_mesh = child
	assert(enemy_mesh != null, "Roach pose missing")
	enemy = CharacterBody3D.new()
	enemy.name = "CaveCreature"
	enemy.collision_layer = 2
	enemy.collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 6
	capsule.height = 12
	collision.shape = capsule
	collision.position.y = 6
	enemy.add_child(collision)
	stage.add_child(enemy)
	enemy_mesh.reparent(enemy)
	enemy_mesh.position = Vector3.ZERO
	for pairs in [occluder_pairs, light_pairs]:
		for pair in pairs:
			if pair[0] == enemy_mesh:
				enemy_copies.append(pair[1])
	if not _build_enemy_animation():
		return
	player.collision_mask |= 2
	# Reviewed region751 has a near edge 0/3 and far edge 1/2. Keep the
	# encounter inside its recovered floor polygon; no new room geometry.
	var found := false
	for face in data.faces:
		if int(face.region) == 751:
			var near_end: Vector3 = (point(face.points[0]) + point(face.points[3])) * 32 + native_translation
			var far_end: Vector3 = (point(face.points[1]) + point(face.points[2])) * 32 + native_translation
			player_spawn = near_end.lerp(far_end, 0.25) + Vector3.UP * 34
			enemy_spawn = near_end.lerp(far_end, 0.65) + Vector3.UP
			exit_position = near_end.lerp(far_end, 0.9)
			found = true
			break
	assert(found, "Encounter floor region missing")
	exit_label = Label.new()
	exit_label.text = "Passage"
	exit_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	exit_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	exit_label.add_theme_constant_override("shadow_offset_x", 2)
	exit_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.get_parent().add_child(exit_label)
	encounter_ready = true
	_restart_encounter()
	get_window().title = "Lands of Lore II — Cavern encounter prototype"

func _restart_encounter() -> void:
	encounter = Encounter.new()
	encounter.configure_attack(animation.attack_impact_frame, animation.action_textures[5].size(), animation.PREVIEW_FPS)
	player.global_position = player_spawn
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.look_at(Vector3(enemy_spawn.x, player_spawn.y, enemy_spawn.z))
	camera.rotation = Vector3.ZERO
	camera.look_at(enemy_spawn + Vector3.UP * 6)
	enemy.global_position = enemy_spawn
	enemy.velocity = Vector3.ZERO
	enemy.collision_layer = 2
	enemy_mesh.visible = true
	enemy_mesh.position = Vector3.ZERO
	animation.reset()
	enemy_facing = Vector2(player_spawn.x - enemy_spawn.x, enemy_spawn.z - player_spawn.z)
	_update_enemy_direction()
	_apply_enemy_frame()
	collectible.restore([])
	_sync_collected_visuals()
	props_root.visible = true
	attack_requested = false
	interaction_requested = false
	interaction_available = false
	flying = false
	save_notice = ""
	save_notice_until = 0
	_sync_enemy_visuals()

func _reset() -> void:
	if encounter_ready:
		_restart_encounter()
	else:
		super._reset()

func _unhandled_input(event: InputEvent) -> void:
	if not encounter_ready:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart_encounter()
			return
		# This bounded encounter has no checkpoint/fly cheats or save integration.
		if event.keycode in [KEY_N, KEY_P, KEY_F, KEY_F5, KEY_F9]:
			return
		if event.keycode == KEY_E and encounter.player_health <= 0:
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			attack_requested = true
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

func _clear_ray(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid(), enemy.get_rid()])
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _try_player_strike() -> bool:
	var destination := enemy.global_position + Vector3.UP * 6
	var delta := destination - camera.global_position
	var aimed := delta.length() > 0.01 and (-camera.global_basis.z).dot(delta.normalized()) >= 0.9
	var hit := encounter.strike(delta.length() <= PLAYER_REACH, aimed, _clear_ray(camera.global_position, destination))
	if hit:
		_save_feedback("Creature defeated." if encounter.enemy_health == 0 else "Strike landed.")
	return hit

func _physics_process(delta: float) -> void:
	if not encounter_ready:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or encounter.player_health <= 0:
		attack_requested = false
		interaction_requested = false
		interaction_available = false
		player.velocity = Vector3.ZERO
		enemy.velocity = Vector3.ZERO
		return
	super._physics_process(delta)
	if attack_requested:
		_try_player_strike()
	attack_requested = false
	var separation := player.global_position - enemy.global_position
	var distance := Vector2(separation.x, separation.z).length()
	var sight := absf(separation.y) < 72 and _clear_ray(enemy.global_position + Vector3.UP * 12, player.global_position + Vector3.UP * 8)
	var damage := encounter.advance(delta, distance, sight)
	if damage > 0:
		_save_feedback("You were hit." if encounter.player_health > 0 else "You fell. Press R to retry.")
	enemy.velocity.x = 0
	enemy.velocity.z = 0
	if encounter.phase == Encounter.Phase.PURSUING:
		var direction := Vector3(separation.x, 0, separation.z).normalized()
		enemy.velocity.x = direction.x * ENEMY_SPEED
		enemy.velocity.z = direction.z * ENEMY_SPEED
	var previous_position := enemy.global_position
	if encounter.enemy_health > 0:
		enemy.velocity.y = 0.0 if enemy.is_on_floor() else enemy.velocity.y - 128 * delta
		enemy.move_and_slide()
	enemy.collision_layer = 2 if encounter.enemy_health > 0 else 0
	var travel := enemy.global_position - previous_position
	if Vector2(travel.x, travel.z).length() > 0.001:
		enemy_facing = Vector2(travel.x, -travel.z)
	_update_enemy_direction()
	# Source hit marker drives the shared attack clock; seconds/FPS remain provisional.
	if encounter.enemy_health <= 0:
		animation.play_action(14)
	elif encounter.phase in [Encounter.Phase.WINDUP, Encounter.Phase.RECOVERY]:
		animation.play_action(5)
	else:
		animation.clear_action()
	if animation.action_key == 5:
		animation.set_action_elapsed(encounter.attack_elapsed())
	else:
		animation.advance(delta, encounter.phase == Encounter.Phase.PURSUING and Vector2(travel.x, travel.z).length() > 0.001)
	enemy_mesh.visible = encounter.enemy_health > 0 or not animation.action_finished()
	_apply_enemy_frame()
	enemy_mesh.position.y = 0.0
	var exit_delta := player.global_position - exit_position
	var inside := Vector2(exit_delta.x, exit_delta.z).length() <= 22 and absf(exit_delta.y) <= 48
	if encounter.enter_exit(collectible.collected, inside):
		_save_feedback("Passage reached. Section complete.")
	_sync_enemy_visuals()

func _build_enemy_animation() -> bool:
	var error := animation.load_assets()
	if not error.is_empty():
		push_error(error)
		get_tree().quit(1)
		return false
	var quad: QuadMesh = enemy_mesh.mesh.duplicate()
	quad.size = animation.canvas_size * animation.world_units_per_pixel
	quad.center_offset = animation.centre_offset
	# Dummies share materials. Isolate this actor in every render pass before
	# changing textures, or the untouched roach dummy would animate as well.
	quad.material = quad.material.duplicate()
	enemy_mesh.mesh = quad
	animation_materials.append(quad.material)
	for copy in enemy_copies:
		copy.mesh = quad
		copy.material_override = copy.material_override.duplicate()
		animation_materials.append(copy.material_override)
		if copy.layers == 64:
			light_materials.append(copy.material_override)
	_apply_enemy_frame()
	return true

func _apply_enemy_frame() -> void:
	if animation.textures.is_empty() or (animation.frame_index == applied_frame and animation.view_slot == applied_view and animation.action_key == applied_action):
		return
	applied_frame = animation.frame_index
	applied_view = animation.view_slot
	applied_action = animation.action_key
	for material in animation_materials:
		material.set_shader_parameter("indices", animation.textures[applied_frame])

func _update_enemy_direction() -> void:
	var relative := camera.global_position - enemy.global_position
	# Geometry maps original(x,y) to Godot(x,-z).
	animation.select_direction(Vector2(relative.x, -relative.z), enemy_facing)

func _sync_enemy_visuals() -> void:
	for copy in enemy_copies:
		copy.global_transform = enemy_mesh.global_transform
		copy.visible = enemy_mesh.is_visible_in_tree()

func _process(delta: float) -> void:
	if not encounter_ready:
		return
	_sync_enemy_visuals()
	super._process(delta)
	var objective := "Defeat the cave creature"
	if encounter.enemy_health == 0:
		objective = "Collect the cavern sample (E)" if not collectible.collected else "Reach the passage marker"
	if encounter.complete:
		objective = "Section complete — R to play again"
	elif encounter.player_health == 0:
		objective = "You fell — R to retry"
	hud.text = "Cavern encounter · Prototype combat\nWASD + mouse · Left click strike · E collect · R restart · Esc release\nHealth %d/%d · Creature %d/%d\n%s" % [encounter.player_health, Encounter.PLAYER_HEALTH, encounter.enemy_health, Encounter.ENEMY_HEALTH, objective]
	if encounter.phase == Encounter.Phase.WINDUP:
		hud.text += "\nCreature preparing to strike — step back!"
	if Time.get_ticks_msec() < save_notice_until:
		hud.text += "\n" + save_notice
	var marker_position := exit_position + Vector3.UP * 20
	exit_label.visible = encounter.enemy_health == 0 and collectible.collected and not encounter.complete and encounter.player_health > 0 and not camera.is_position_behind(marker_position)
	if exit_label.visible:
		exit_label.position = camera.unproject_position(marker_position) - Vector2(25, 12)
