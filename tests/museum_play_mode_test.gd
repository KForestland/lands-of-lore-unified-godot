extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func key(scene: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	scene._unhandled_input(event)
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	assert(not scene.development_mode and not scene.development_overlay.visible)
	key(scene, KEY_T)
	key(scene, KEY_F)
	key(scene, KEY_G)
	assert(scene.sword_transfer.phase == "waiting" and not scene.flying and scene.museum_props.visible)
	key(scene, KEY_F3)
	assert(scene.development_mode and scene.development_overlay.visible)
	key(scene, KEY_T)
	key(scene, KEY_F)
	key(scene, KEY_G)
	assert(scene.sword_transfer.phase == "carrying" and scene.flying and not scene.museum_props.visible)
	key(scene, KEY_F3)
	assert(not scene.flying and scene.museum_props.visible and not scene.development_overlay.visible)
	assert(scene.sword_transfer.phase == "carrying")
	key(scene, KEY_ESCAPE)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("Museum play mode passed: clean default, protected debug keys, F3 toggle and restored walk/props")
	scene.free()
	quit()
