extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene); current_scene = scene
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(180): await physics_frame
	assert(scene.player.is_on_floor(), "Museum arrival did not ground")
	var floor_y: float = scene.player.position.y
	var key := InputEventKey.new(); key.keycode = KEY_SPACE; key.pressed = true
	scene._unhandled_input(key)
	assert(scene.jump_requested, "Space did not request jump")
	for i in range(6): await physics_frame
	assert(scene.player.position.y > floor_y + 2, "Jump did not lift player")
	assert(not scene.request_jump(), "Air jump admitted")
	for i in range(150): await physics_frame
	assert(scene.player.is_on_floor(), "Jump failed to land")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not scene.request_jump(), "Cursor-open jump admitted")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused = true
	assert(not scene.request_jump(), "Paused jump admitted")
	paused = false
	var overlay = root.get_node("PlaytestLocation")
	overlay._process(0.0)
	assert("Museum" in overlay.location and "X " in overlay.location and "Y " in overlay.location and "H " in overlay.location)
	key.keycode = KEY_F8; overlay._input(key)
	assert(DisplayServer.clipboard_get() == overlay.location, "F8 location copy failed")
	print("PASS Museum Space jump, air/cursor/pause rejection, landing and location clipboard")
	quit()
