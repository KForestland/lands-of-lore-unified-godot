extends SceneTree
## G-05 spot 06-58-50 (owner F10, Citadel vault): standing flush on a generic mover's flat top, the player must be able to
## walk off. Pinned state: the owner's own save from that report (tests/fixtures/g05_vault). Red/green in one test:
## with meta lol2_mover_trimesh_tops (the old all-trimesh mover collision) one second of W moves him less than 1 unit
## (move_and_slide spends every slide on zero-depth floor contacts with Movable83's top); with the convex top slabs he
## walks at least 40 units. Rendered (mouse capture drives the walk input).
const SAVE := "res://tests/fixtures/g05_vault/owner_06-58-50_save.json"
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	printerr("FAIL mover top slab: ", message)
	quit(1)
func walk(old_tops: bool) -> float:
	if old_tops: set_meta("lol2_mover_trimesh_tops", true)
	elif has_meta("lol2_mover_trimesh_tops"): remove_meta("lol2_mover_trimesh_tops")
	if is_instance_valid(current_scene): current_scene.queue_free(); current_scene = null
	await process_frame
	var error: String = load("res://scripts/lol2/game_save.gd").load_file(self, ProjectSettings.globalize_path(SAVE))
	if not error.is_empty(): printerr(error); return -1.0
	var scene: Node = null
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): scene = current_scene; break
	if scene == null: return -1.0
	for i in 60: await physics_frame
	var body: CharacterBody3D = scene.player
	var under := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 30, body.global_position + Vector3.DOWN * 60, 1, [body.get_rid()])
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(under)
	if hit.is_empty() or not str((hit.collider as Node).get_path()).contains("Movable83"): printerr("not standing on Movable83: ", hit); return -1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var start := body.global_position
	var key := InputEventKey.new(); key.keycode = KEY_W; key.physical_keycode = KEY_W; key.pressed = true
	Input.parse_input_event(key)
	for i in 60: await physics_frame
	key = key.duplicate(); key.pressed = false; Input.parse_input_event(key)
	return Vector2(body.global_position.x - start.x, body.global_position.z - start.z).length()
func run() -> void:
	set_meta("original_game_verified", true)
	var old_moved: float = await walk(true)
	if old_moved < 0.0: return fail("old collision: could not load the pinned state on Movable83")
	if old_moved >= 1.0: return fail("old collision no longer sticks (moved %.1f): the test is not red any more" % old_moved)
	var new_moved: float = await walk(false)
	if new_moved < 0.0: return fail("new collision: could not load the pinned state on Movable83")
	if new_moved < 40.0: return fail("stuck on the vault top: moved %.1f in 1 s of W" % new_moved)
	print("PASS mover top slab: old trimesh tops %.1f units, convex slabs %.1f units in 1 s of W" % [old_moved, new_moved])
	quit(0)
