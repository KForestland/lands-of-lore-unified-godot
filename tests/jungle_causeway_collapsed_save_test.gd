extends SceneTree
## Causeway save/reload pair, process 1 of 2 (headless; jungle_causeway_collapsed_reload_test reloads in a NEW process,
## same user dir). Collapses the causeway through a real exit ending (local48 = 3 -> predicate50 -> g16986, which runs
## prop4648 event20 -> g17352), skips the movie, checks the live world and keeps user://tests/causeway_collapsed.json.
const World = preload("res://tests/jungle_causeway_world.gd")
const PATH := "user://tests/causeway_collapsed.json"
const FLAGS := {"shared": {"13": 0, "14": 1, "18": 1, "47": 0}, "locals": {"41": 0, "49": 0, "51": 0}}
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_causeway_collapsed_save: ", message); quit(1)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	scene.exit_encounter.set_physics_process(false)
	for i in 2: await physics_frame
	var error := World.compare(scene, false)
	if not error.is_empty(): return fail("Before the ending: " + error)
	var ctrl = scene.exit_encounter
	ctrl.encounter.locals["48"] = 3
	ctrl.request_prop4398_event20(FLAGS.duplicate(true))
	if str(ctrl.encounter.ending.get("movie", "")) != "HW-BRDGE.VQA": return fail("Ending did not start")
	ctrl.skip_line()
	for i in 2: await physics_frame
	error = World.compare(scene, true)
	if not error.is_empty(): return fail("After the ending: " + error)
	error = scene.quicksave(PATH)
	if not error.is_empty(): return fail("Save: " + error)
	print("PASS jungle_causeway_collapsed_save: ending g16986 -> g17352 collapsed the causeway; kept ", PATH)
	quit(0)
