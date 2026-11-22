extends SceneTree
## Owner r19p 2026-11-17 (F10 14-50-30 at -1733, 1088): 'this guy should not be here and should not block the rest of the
## game' - clubhouse guard21, woken on approach for anyone. Lead rule: he appears only for a tribe member; before that the
## clubhouse doors answer E with his line. From the owner's own save (not a member, guard saved present): after load the
## guard is gone (no body, no collision), real E at the doors gives 'The clubhouse is reserved for members of the tribe.',
## the doors stay shut, and walking around in front of the doors does not bring him back. Input: local owner save.
const GameSave = preload("res://scripts/lol2/game_save.gd")
const SAVE := "res://tmp/l8_club_inputs/owner_145030.json"
const SAVE_SHA := "10975df364b70638c0616704e7056b87d17c03f43558f570c3fb01106b631bc2"

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	push_error("FAIL l8_clubhouse_guard_input: " + message); quit(1)

func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()

func run() -> void:
	if DisplayServer.get_name() == "headless" or Engine.time_scale != 1.0: return fail("rendered ordinary clock")
	if not FileAccess.file_exists(SAVE) or FileAccess.get_sha256(SAVE) != SAVE_SHA: return fail("owner save missing or changed (local input " + SAVE + ")")
	var err: String = GameSave.load_file(self, ProjectSettings.globalize_path(SAVE))
	if not err.is_empty(): return fail("load: " + err)
	var session: Node = root.get_node("GameSession")
	var scene: Node = null
	for i in 3000:
		await process_frame
		scene = current_scene
		if scene != null and scene.scene_file_path.ends_with("darker_jungle.tscn") and is_instance_valid(scene.get("player")) and session.pending_resume.is_empty() and not session.changing_scene: break
	if scene == null or not scene.scene_file_path.ends_with("darker_jungle.tscn"): return fail("the save did not resume L8")
	for i in 30: await physics_frame
	var club: Node = scene.get_node("L8Clubhouse")
	var actor: Dictionary = scene.act2_creatures.state.actors["21"]
	if club.member(): return fail("the owner's save is expected to be before the initiation")
	if actor.present: return fail("guard21 still present for a non-member after load")
	if scene.act2_creatures.bodies["21"].collision_layer != 0: return fail("absent guard21 still collides")
	# Real walk in front of the doors (within his old 300 wake range), then real E at them.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player.global_position = Vector3(-1720, 32.5, 1150); scene.player.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	scene.camera.look_at(club.AIM, Vector3.UP)
	var yaw: float = scene.camera.global_rotation.y
	var m := InputEventMouseMotion.new(); m.relative = Vector2(-wrapf(yaw - scene.player.rotation.y, -PI, PI) / 0.003, 0); Input.parse_input_event(m); Input.flush_buffered_events()
	for i in 10: await physics_frame
	scene.camera.look_at(club.AIM, Vector3.UP)
	for i in 3: await process_frame
	print("HINT '%s' reachable %s" % [club.hint.text, club.reachable()])
	if actor.present: return fail("walking up to the doors woke guard21 for a non-member")
	if club.hint.text != "The clubhouse is reserved for members of the tribe.": return fail("the doors promise to open for a non-member (hint '%s')" % club.hint.text)
	key(KEY_E, true); await process_frame; key(KEY_E, false)
	for i in 5: await process_frame
	var said: Dictionary = club.interact()
	print("E -> ", said)
	if said.ok or said.reason != "The clubhouse is reserved for members of the tribe.": return fail("the doors do not give the guard's line: %s" % str(said))
	if club.state().opened: return fail("the doors opened for a non-member")
	print("PASS l8_clubhouse_guard_input: no guard for a non-member, the doors say why they stay shut")
	quit()
