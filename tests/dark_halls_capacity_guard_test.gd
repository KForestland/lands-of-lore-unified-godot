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
	var control: Dictionary = scene.loot.source.controls[0]
	var excluded: String = control.grants[0].id
	var full: Array = []
	for id in Catalog.ids("jungle"):
		if id != excluded and id != "jungle:kelsrick:Fine_Longsword" and full.size() < 64: full.append(id)
	if full.size()!=64 or not Catalog.validate_carried(full,"jungle").is_empty(): return fail("Invalid full fixture")
	scene.carried_collected = full.duplicate()
	scene.equipped_item = ""; scene.equipped_armor = ""
	var before: String = scene.quicksave("user://tests/capacity_before.json")
	if not before.is_empty(): return fail("Baseline full save rejected: "+before)
	var position := Vector3(control.position[0],control.position[1],control.position[2])
	scene.player.global_position = position + Vector3(60,34,0)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(position + Vector3(0,24,0))
	await physics_frame
	if int(scene.loot.target().get("control",-1)) != int(control.control): return fail("Wrong aimed control")
	var accepted: bool = scene.loot.take()
	var after: String = scene.quicksave("user://tests/capacity_after.json")
	print("CAPACITY_RESULT accepted=",accepted," count=",scene.carried_collected.size()," uses=",scene.loot.taken()," save_error=",after)
	if accepted or scene.carried_collected != full or not after.is_empty() or int(scene.loot.taken().get(str(int(control.control)),0)) != 0: return fail("Full pickup mutated inventory/history or invalidated save")
	scene.carried_collected.pop_back()
	if not scene.loot.take(): return fail("Pickup refused after freeing one slot")
	if scene.carried_collected.size()!=64 or not excluded in scene.carried_collected: return fail("Retry did not grant exactly one item")
	if int(scene.loot.taken().get(str(int(control.control)),0))!=1: return fail("Retry changed use count incorrectly")
	if not scene.quicksave("user://tests/capacity_retry.json").is_empty(): return fail("Retry save rejected")
	print("PASS capacity_guard: full valid64 refusal preserves inventory/use count/save; freeing one slot allows exactly one pickup and valid save.")
	quit(0)
