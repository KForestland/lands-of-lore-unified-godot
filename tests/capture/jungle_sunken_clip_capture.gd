extends SceneTree
## Rendered before/after captures for the gorge clip (owner r12e F10 2026-10-25 11:02). Not a registered test; run with
##   python3 ~/opus_work/ai_tools/godot_capture.py --project . --out OUT --script res://tests/capture/jungle_sunken_clip_capture.gd
## Writes user://capture/{before,after}_{owner,gorge_east,channel}.png. "before" turns the clip off on the same build.
const VIEWS := {
	# The owner's F10 camera: position (3152.96, 42.04, -4415.03), pitch 0.039, yaw 2.7078.
	"owner": [Vector3(3152.96, 42.04, -4415.03), 2.70779609680176, 0.0390083603560925],
	# The open gorge from the east bank (region 4784, floor 0), looking west.
	"gorge_east": [Vector3(3300.0, 42.0, -3950.0), PI / 2.0, -0.2],
	# From the river channel (region 3293, floor -180) south toward the waterfall openings.
	"channel": [Vector3(3000.0, -138.0, -3700.0), 0.0, 0.1],
}
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://capture")
	get_root().size = Vector2i(1280, 720)
	for mode in ["before", "after"]:
		var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
		scene.clip_sunken_groups = mode == "after"
		root.add_child(scene); current_scene = scene
		for i in 1500:
			await process_frame
			if scene.get("ready_for_review"): break
		for view in VIEWS:
			var pose: Array = VIEWS[view]
			scene.player.global_position = pose[0] - (scene.camera.global_position - scene.player.global_position)
			scene.player.rotation.y = pose[1]
			scene.camera.rotation.x = pose[2]
			for i in 20: await process_frame
			get_root().get_texture().get_image().save_png("user://capture/%s_%s.png" % [mode, view])
			print("captured %s_%s camera %s" % [mode, view, scene.camera.global_position])
		scene.queue_free()
		for i in 5: await process_frame
	quit(0)
