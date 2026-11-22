extends Node
## --hold-after-load (lead 2026-11-12): after --load-bundle, the game stays paused at the loaded spot until the first key
## press, so the owner can look at his own report's view before anything moves (glacier slides, creatures). While held,
## mouse look still works (same 0.003 rad per pixel as the hosts) and portal drawing keeps following the camera.
## The node is added to the tree root, so it survives the change from the gate to the loaded area.
const HINT := "Loaded at your report - press any key to continue"
const WAIT_FRAMES := 1800
var scene: Node
var held := false
var layer: CanvasLayer
var saved_modes: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "LoadHold"

func _process(_delta: float) -> void:
	if held: return
	var current := get_tree().current_scene
	if current == null or current.get("player") == null or not current.is_node_ready() or current.scene_file_path.ends_with("original_game_gate.tscn"): return
	scene = current
	_hold()

func _hold() -> void:
	held = true
	get_tree().paused = true
	# Portal drawing follows the camera while held (it would otherwise freeze with the pause).
	var vis: Node = scene.get("region_visibility")
	if vis != null:
		saved_modes.append([vis, vis.process_mode])
		vis.process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 120
	var label := Label.new()
	label.text = HINT
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = Vector2(24, 64)
	layer.add_child(label)
	add_child(layer)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("LOAD HOLD at ", scene.player.global_position)

func _input(event: InputEvent) -> void:
	if not held or scene == null: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		scene.player.rotate_y(-event.relative.x * 0.003)
		var camera: Camera3D = scene.get("camera")
		var limit := float(scene.get("pitch_limit")) if scene.get("pitch_limit") != null else 1.3
		if camera != null: camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -limit, limit)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		# F10 also reaches the report panel (the owner may report straight from the held view); other keys only release.
		if event.keycode != KEY_F10: get_viewport().set_input_as_handled()
		release()

func release() -> void:
	held = false
	scene = null
	for row in saved_modes:
		if is_instance_valid(row[0]): row[0].process_mode = row[1]
	get_tree().paused = false
	print("LOAD HOLD released")
	queue_free()
