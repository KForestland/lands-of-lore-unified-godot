extends SceneTree
## Rendered before/after captures (owner r12e report 5) from the owner's F10 camera (5529.7, cam -72, -3715.0, yaw 1.4214)
## and from the west bank looking east. Saves user://capture/causeway_{before,after}_{owner,west}.png and requires the
## after image to differ from the before image at the owner's view (the causeway floor is gone).
const FLAGS := {"shared": {"13": 0, "14": 1, "18": 1, "47": 0}, "locals": {"41": 0, "49": 0, "51": 0}}
const VIEWS := {"owner": [Vector3(5529.75, -71.96, -3714.95), 1.42135262489319, -0.15], "west": [Vector3(4250.0, -72.0, -3700.0), -PI / 2.0, -0.2]}
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_causeway_capture: ", message); quit(1)

func shoot(mode: String) -> Dictionary:
	var images := {}
	for view in VIEWS:
		var pose: Array = VIEWS[view]
		scene.player.global_position = pose[0] - (scene.camera.global_position - scene.player.global_position)
		scene.player.rotation.y = pose[1]
		scene.camera.rotation.x = pose[2]
		for i in 20: await process_frame
		var image: Image = root.get_texture().get_image()
		image.save_png("user://capture/causeway_%s_%s.png" % [mode, view])
		images[view] = image
	return images

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://capture")
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	scene.exit_encounter.set_physics_process(false)
	var before: Dictionary = await shoot("before")
	var ctrl = scene.exit_encounter
	ctrl.encounter.locals["48"] = 3
	ctrl.request_prop4398_event20(FLAGS.duplicate(true))
	ctrl.skip_line()
	var after: Dictionary = await shoot("after")
	if before.owner.get_data() == after.owner.get_data(): return fail("Owner view unchanged by the collapse")
	print("PASS jungle_causeway_capture: before/after saved (owner, west); owner view changed")
	quit(0)
