extends SceneTree
## Owner F10 06-47-40 ("ruloi entrance do not work"): from his own save (tests/fixtures/g05_ruloi), standing in the ice
## corridor where the Citadel first comes into view (about 900 units from the deck control 74, reach 120), nothing is
## aimable, and the hint line names where the way in is. Turned away, the hint is gone. Rendered (camera/hint layer).
const SAVE := "res://tests/fixtures/g05_ruloi/owner_06-47-40_save.json"
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l12 citadel hint: ", m)
	quit(1)
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
	var citadel: Node = scene.get_node("L12Citadel")
	var aim: Vector3 = citadel.entrance_aim()
	var to: Vector3 = aim - scene.player.global_position; to.y = 0
	scene.player.rotation.y = atan2(-to.x, -to.z); scene.camera.rotation.x = 0.0
	for i in 10: await process_frame
	if scene.progression.aimed_exit() != "": return fail("an exit is already aimable from the corridor")
	if citadel.hint.text != citadel.ENTRANCE_HINT: return fail("no entrance hint facing the Citadel ('%s')" % citadel.hint.text)
	scene.player.rotation.y += PI
	for i in 10: await process_frame
	if citadel.hint.text == citadel.ENTRANCE_HINT: return fail("hint still shown facing away")
	# Within reach of control 74 the normal E prompt takes over: no corridor hint.
	var start: Vector3 = scene.player.global_position
	var flat: Vector3 = aim - start; flat.y = 0
	scene.player.global_position = Vector3(aim.x, start.y, aim.z) - flat.normalized() * 100.0
	for i in 20: await physics_frame
	var near_to: Vector3 = aim - scene.player.global_position; near_to.y = 0
	scene.player.rotation.y = atan2(-near_to.x, -near_to.z); scene.camera.rotation.x = 0.0
	for i in 10: await process_frame
	if scene.progression.aimed_exit() != "control:74": return fail("control 74 not aimable 100 units from the deck (%s)" % scene.progression.aimed_exit())
	if citadel.hint.text == citadel.ENTRANCE_HINT: return fail("corridor hint still shown within reach of control 74")
	# After the entrance movie (state movie_seen), a later save and reload: no hint at the owner's corridor spot.
	var Save = load("res://scripts/lol2/game_save.gd")
	var s: Dictionary = citadel.state().duplicate(true); s.movie_seen = true; scene.quest_state[citadel.State.KEY] = s
	scene.player.global_position = start
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests/l12_citadel_hint"))
	var later := "user://tests/l12_citadel_hint/after_movie.json"
	var werr: String = Save.write_document(later, Save.make_document(scene, Save.AUTOSAVE))
	if not werr.is_empty(): return fail("save after movie: " + werr)
	var lerr: String = Save.load_file(self, ProjectSettings.globalize_path(later))
	if not lerr.is_empty(): return fail("reload after movie: " + lerr)
	var reloaded: Node = null
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != scene and current_scene.get("player") is Node3D and current_scene.is_node_ready(): reloaded = current_scene; break
	if reloaded == null: return fail("reloaded L12 did not open")
	for i in 60: await physics_frame
	var rc: Node = reloaded.get_node("L12Citadel")
	if not bool(rc.state().movie_seen): return fail("movie_seen lost across save/reload")
	var back: Vector3 = aim - reloaded.player.global_position; back.y = 0
	reloaded.player.rotation.y = atan2(-back.x, -back.z); reloaded.camera.rotation.x = 0.0
	for i in 10: await process_frame
	if rc.hint.text == rc.ENTRANCE_HINT: return fail("hint shown again after the movie and a reload")
	print("PASS l12 citadel hint: corridor 900 from the deck control, nothing aimable, hint '", rc.ENTRANCE_HINT, "' facing it, gone facing away, gone within reach (control 74 aimable), gone for good after the movie (save/reload)")
	quit(0)
