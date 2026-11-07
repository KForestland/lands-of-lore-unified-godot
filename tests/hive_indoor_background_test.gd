extends SceneTree
## Owner r12h 2026-10-25 ("can see the sky box"): the Hive showed the authored daylight sky through every gap. The original
## clears to black indoors (longplay 40:00-43:52, 91:36-92:18), so the Hive background is black; the Jungle keeps its sky.
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL hive_indoor_background: ", message); quit(1)

func environment_of(scene: Node) -> Environment:
	for child in scene.find_children("*", "WorldEnvironment", true, false):
		return child.environment
	return null

func run() -> void:
	var result := {}
	for path in ["res://scenes/lol2/hive_review.tscn", "res://scenes/lol2/jungle_walkthrough.tscn"]:
		var scene = load(path).instantiate(); root.add_child(scene); current_scene = scene
		for i in 1500:
			await process_frame
			if scene.get("ready_for_review"): break
		if not scene.get("ready_for_review"): return fail("%s not ready" % path)
		var environment := environment_of(scene)
		if environment == null: return fail("%s has no WorldEnvironment" % path)
		result[path] = [environment.background_mode, environment.background_color]
		scene.queue_free()
		for i in 5: await process_frame
	var hive: Array = result["res://scenes/lol2/hive_review.tscn"]
	if hive[0] != Environment.BG_COLOR or hive[1] != Color.BLACK: return fail("Hive background is not black: %s" % [hive])
	if result["res://scenes/lol2/jungle_walkthrough.tscn"][0] != Environment.BG_SKY: return fail("Jungle lost its sky")
	print("PASS hive_indoor_background: Hive clears to black, Jungle keeps the sky")
	quit(0)
