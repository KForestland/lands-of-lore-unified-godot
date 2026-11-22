extends SceneTree
## Grok 2026-11-18 (r19p2, way up L12 by the screen alone): at the Citadel deck, held at X 3643.1 Y -19274.6 H -1206,
## the aimed E on control 74 played the entrance movie and entered the Citadel, but the screen named no E. The door-prompt
## rule covers door movables only; control 74 is an exit control. From the owner's L12 save (tests/fixtures/g05_ruloi,
## tracked) the player is put at Grok's deck stand, faces away (no line), turns to the deck aim (the line reads
## 'E — Enter the Citadel'), and a real E key starts the entrance (the movie overlay and the pending level change).
## Rendered (camera, hint layer, movie overlay).
const SAVE := "res://tests/fixtures/g05_ruloi/owner_06-47-40_save.json"
const LINE := "E — Enter the Citadel"
const STAND := Vector3(3643.1, -1206.0, -19274.6)
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l12 citadel enter prompt: ", m)
	quit(1)
func face(scene: Node, target: Vector3) -> void:
	var to: Vector3 = target - scene.camera.global_position
	scene.player.rotation.y = atan2(-to.x, -to.z)
	scene.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
		for i in 3: await process_frame
func run() -> void:
	set_meta("original_game_verified", true)
	var error: String = load("res://scripts/lol2/game_save.gd").load_file(self, ProjectSettings.globalize_path(SAVE))
	if not error.is_empty(): return fail(error)
	var scene: Node = null
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): scene = current_scene; break
	if scene == null: return fail("L12 did not open")
	for i in 60: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player.global_position = STAND + Vector3.UP * 4.0
	scene.player.velocity = Vector3.ZERO
	for i in 60: await physics_frame
	var at: Vector3 = scene.player.global_position
	if Vector2(at.x - STAND.x, at.z - STAND.z).length() > 4.0 or absf(at.y - STAND.y) > 12.0: return fail("did not settle at Grok's deck stand (%s)" % str(at))
	var citadel: Node = scene.get_node("L12Citadel")
	var aim: Vector3 = citadel.entrance_aim()
	var prog: Node = scene.progression
	face(scene, at + (at - aim) * Vector3(1, 0, 1))
	for i in 10: await process_frame
	if prog.interaction_hint.text == LINE: return fail("prompt shown facing away from the deck")
	face(scene, aim)
	for i in 10: await process_frame
	if prog.aimed_exit() != "control:74": return fail("control 74 not aimed from the stand (%s)" % prog.aimed_exit())
	if prog.interaction_hint.text != LINE: return fail("no E line at the deck ('%s')" % prog.interaction_hint.text)
	await key(KEY_E)
	if citadel.pending.is_empty() and scene.get("video_overlay") == null: return fail("E at the deck did not start the entrance")
	print("PASS l12 citadel enter prompt: at Grok's deck stand ", at, " facing away no line; aimed at control 74 the line reads '", LINE, "'; real E starts the entrance")
	quit(0)
