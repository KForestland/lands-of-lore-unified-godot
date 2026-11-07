extends SceneTree
## Exercise the real scene change, not just the binder's request log. Coordinates below in callers are frozen
## witnesses from decoded arrival records and nav floors; original camera height/heading remain adapters.
var failures := 0
func specification() -> Dictionary: return {}
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var spec := specification()
	Engine.set_meta("lol2_enhanced", false)
	var scene = load(spec.scene).instantiate()
	root.add_child(scene)
	current_scene = scene
	# Inspect immediately after ready: physics must not move an arrival before it is measured.
	check(scene.player.position.distance_to(spec.start) < 0.01, "native preview start %s" % scene.player.position)
	var binder = scene.progression
	check(binder != null and binder.native != null, "native binder attached")
	if binder == null: quit(1); return
	binder.set_physics_process(false)
	scene.player.set_physics_process(false)
	var results: Array
	if spec.has("region"):
		results = binder.enter_region(spec.region)
	else:
		results = binder.fire(spec.object, spec.event, spec.input)
	var ran := false
	for row in results:
		if int(row.group) == int(spec.group) and str(row.status) == "ran": ran = true
	check(ran, "exit group ran: %s" % [results])
	check(binder.level_changes.size() == 1, "one native level-change request")
	if binder.level_changes.size() != 1: quit(1); return
	check(int(binder.level_changes[0].level) == int(spec.level) and int(binder.level_changes[0].selector) == int(spec.selector), "decoded destination and selector")
	if spec.get("story_gate", false):
		# The raw native request must not bypass STORY039's conversation admission.
		for frame in 3: await process_frame
		check(is_instance_valid(scene) and current_scene == scene, "story gate refuses unearned native request")
		check(not scene.get_node("L12Citadel").state().talked and not scene.get_node("L12Citadel").state().movie_seen, "refusal does not seed conversation/movie")
		if failures == 0: print("PASS L12 native request and Citadel story refusal; earned transition covered by l12_citadel_earned_test")
		quit(0 if failures == 0 else 1); return
	# scene_changed arrives after the destination's ready, before its first physics step.
	await scene_changed
	var destination = current_scene
	check(destination != null and destination.scene_file_path == spec.destination, "actual destination scene")
	if destination == null: quit(1); return
	destination.player.set_physics_process(false)
	if destination.progression != null: destination.progression.set_physics_process(false)
	check(destination.start_selector == spec.selector, "arrival selector consumed")
	check(destination.arrived_by_level_change, "native arrival flag")
	check(destination.player.position.distance_to(spec.position) < 0.01, "destination native position %s expected %s" % [destination.player.position, spec.position])
	check(absf(wrapf(destination.player.rotation.y - spec.yaw, -PI, PI)) < 0.0001, "destination heading")
	check(not has_meta("lol2_map_start_selector") and not has_meta("lol2_level_change") and not has_meta("lol2_map_preview"), "no stale transition metadata")
	print("%s level transition: %d failures" % [spec.area, failures])
	if failures == 0: print("PASS %s start, native exit, real scene change and arrival" % spec.area)
	quit(0 if failures == 0 else 1)
