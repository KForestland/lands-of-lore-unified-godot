extends SceneTree
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	print("FAIL capacity_review: ",message); quit(1)
func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in 1500:
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Scene not ready")
	scene.set_physics_process(false)
	scene.creatures.set_physics_process(false); scene.creatures.set_process(false)
	scene.creatures.receive_damage("57",999,false)
	for i in 3: await physics_frame
	if not scene.rix.state().dead: return fail("Rix death not applied")
	var excluded: String = scene.rix.rix.corpse.id
	var full: Array = []
	for id in Catalog.ids("jungle"):
		if id != excluded and id != "jungle:kelsrick:Fine_Longsword" and full.size() < 64: full.append(id)
	if full.size()!=64 or not Catalog.validate_carried(full,"jungle").is_empty(): return fail("Invalid full fixture")
	scene.carried_collected = full.duplicate()
	scene.equipped_item = ""; scene.equipped_armor = ""
	var before: String = scene.quicksave("user://tests/rix_capacity_before.json")
	if not before.is_empty(): return fail("Baseline full save rejected: "+before)
	var position: Vector3 = scene.creatures.bodies["57"].global_position
	scene.player.global_position = position + Vector3(60,34,0)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(position + Vector3(0,20,0))
	await physics_frame
	var accepted: bool = scene.rix.take_staff()
	var after: String = scene.quicksave("user://tests/rix_capacity_after.json")
	print("CAPACITY_RESULT accepted=",accepted," count=",scene.carried_collected.size()," uses=",scene.rix.state()," save_error=",after)
	if accepted or scene.carried_collected != full or not after.is_empty() or scene.rix.state().staff: return fail("Full staff pickup mutated inventory/history or invalidated save")
	scene.carried_collected.pop_back()
	if not scene.rix.take_staff(): return fail("Staff pickup refused after freeing one slot")
	if scene.carried_collected.size()!=64 or not excluded in scene.carried_collected or not scene.rix.state().staff: return fail("Retry did not grant staff exactly once")
	if not scene.quicksave("user://tests/rix_capacity_retry.json").is_empty(): return fail("Retry save rejected")
	if scene.rix.take_staff() or scene.carried_collected.size()!=64: return fail("Duplicate staff grant")
	print("PASS rix_capacity_guard: full valid64 refusal preserves staff/inventory/save; free slot allows staff once and valid save.")
	quit(0)
