extends SceneTree
## Causeway save/reload pair, process 2 of 2 (headless, NEW process after jungle_causeway_collapsed_save_test, same user
## dir). Loads the kept save and checks the live nodes: floors at -200 by ray (4445 at -134), the wall sets swapped,
## controls 61/62 drawn and 84 hidden with its panel collision gone, creatures refused on 4429/4448/4447 and the player
## not, the eight props unlinked/moved, and no sound playing from the causeway or a repeated collapse.
const World = preload("res://tests/jungle_causeway_world.gd")
const PATH := "user://tests/causeway_collapsed.json"
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_causeway_collapsed_reload: ", message); quit(1)

func run() -> void:
	if not FileAccess.file_exists(PATH): return fail("No kept save (run jungle_causeway_collapsed_save_test first)")
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	var error: String = scene.quickload(PATH)
	if not error.is_empty(): return fail("Kept save rejected: " + error)
	for i in 30: await physics_frame
	error = World.compare(scene, true)
	if not error.is_empty(): return fail("Reloaded " + error)
	var ctrl = scene.exit_encounter
	if ctrl.active() or ctrl.effect_log.any(func(e): return str(e.type) == "group" and int(e.group) == 17352): return fail("The ending or g17352 ran again on load")
	for node in scene.causeway.find_children("*", "AudioStreamPlayer3D", true, false):
		if node.playing: return fail("Causeway sound playing after load")
	print("PASS jungle_causeway_collapsed_reload: new process loads the collapsed causeway (floors, walls, 61/62/84 + panel, creature refusal, props), no replay, no sound")
	quit(0)
