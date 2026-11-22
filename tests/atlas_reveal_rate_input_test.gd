extends SceneTree
## Owner r19p 2026-11-17 (F10 14-11-30, Jungle -1908, 364): 'the map discovery rate is a bit low, perhaps 2x or 3x'. On the
## Act 1 maps the Atlas revealed only the region under the feet. atlas_explored.gd now also reveals the regions within
## REVEAL_RADIUS (200). From his own save with the Jungle record emptied, a real-W walk of about 900 units reveals 12 regions
## (4 before the change). Fails under 9 (more than double the old rate). Input: local owner save (OWNER_DERIVED.md).
const GameSave = preload("res://scripts/lol2/game_save.gd")
const SAVE := "res://tmp/atlas_rate_inputs/owner_141130.json"
const SAVE_SHA := "bbbaf638fb79612c52dd6e0e9f940e3f2410e0ff7b9d8ddf18feec21a62fb63f"
const MINIMUM := 9

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	push_error("FAIL atlas_reveal_rate_input: " + message); quit(1)

func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()

func count(scene: Node) -> int:
	var row: Variant = (scene.atlas_explored.areas as Dictionary).get("L4_HJ")
	return (row.regions as Array).size() if row is Dictionary else 0

func run() -> void:
	if DisplayServer.get_name() == "headless" or Engine.time_scale != 1.0: return fail("rendered ordinary clock")
	if not FileAccess.file_exists(SAVE) or FileAccess.get_sha256(SAVE) != SAVE_SHA: return fail("owner Jungle save missing or changed (local input " + SAVE + ")")
	var err: String = GameSave.load_file(self, ProjectSettings.globalize_path(SAVE))
	if not err.is_empty(): return fail("load: " + err)
	var session: Node = root.get_node("GameSession")
	var scene: Node = null
	for i in 3000:
		await process_frame
		scene = current_scene
		if scene != null and is_instance_valid(scene.get("player")) and session.pending_resume.is_empty() and not session.changing_scene and scene.get("atlas_explored") is Dictionary: break
	if scene == null or not scene.scene_file_path.ends_with("jungle_walkthrough.tscn"): return fail("the save did not resume the Jungle")
	for i in 60: await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.atlas_explored.areas["L4_HJ"] = {"full": false, "regions": []}
	for i in 3: await process_frame
	var before := count(scene)
	var path := 0.0
	var last: Vector3 = scene.player.global_position
	key(KEY_W, true)
	for i in 900:
		await physics_frame
		path += scene.player.global_position.distance_to(last); last = scene.player.global_position
		if i % 150 == 149:
			var m := InputEventMouseMotion.new(); m.relative = Vector2(300, 0); Input.parse_input_event(m); Input.flush_buffered_events()
	key(KEY_W, false)
	for i in 5: await process_frame
	var total := count(scene)
	print("ATLAS RATE walked %.0f: regions %d (from %d; the old stood-region rule gave 4)" % [path, total, before])
	if path < 600: return fail("real W did not walk (path %.0f)" % path)
	if total < MINIMUM: return fail("the Atlas revealed %d regions on a %.0f walk; at least %d expected" % [total, path, MINIMUM])
	print("PASS atlas_reveal_rate_input: the Jungle Atlas reveals a trail about three regions wide")
	quit()
