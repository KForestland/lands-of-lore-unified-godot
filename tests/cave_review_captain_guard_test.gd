extends SceneTree
## Developer review scene without source combat (cave_encounter.tscn) must load without the guard-population
## captain (previously: cave_captain.gd:50 Nil creature_audio, 164 errors). The production cave keeps Captain56.
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func open(path: String) -> Node:
	var scene=load(path).instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	return scene
func run() -> void:
	var review=await open("res://scenes/lol2/cave_encounter.tscn")
	if not check(review.walkthrough_ready and not review.source_combat_enabled and review.guard_population==null and review.captain==null and review.guard_controls==null,"Review scene still creates captain/guard controls without their population"):return
	var review_save: Dictionary=review._save_state()
	if not check(not review_save.has("captain") and not review_save.has("guard_controls"),"Review save references absent guard systems"):return
	for i in range(30): await physics_frame
	review.queue_free();await process_frame;await process_frame
	var cave=await open("res://scenes/lol2/cave_walkthrough.tscn")
	if not check(cave.walkthrough_ready and cave.guard_population!=null and cave.captain!=null and cave.guard_controls!=null and cave._save_state().has("captain") and cave._save_state().has("guard_controls"),"Production cave lost Captain56"):return
	cave.queue_free();await process_frame
	print("PASS cave review scene loads without guard population or captain; production cave keeps Captain56, guard controls and their save packets")
	quit()
