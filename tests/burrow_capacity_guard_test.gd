extends SceneTree
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const WorldCatalog = preload("res://scripts/lol2/jungle_world_items_catalog.gd")
class TransactionProbe:
	extends "res://scripts/lol2/jungle_river_dam.gd"
	# Only targeting is supplied; production collect, history, and presentation run unchanged.
	func item_target() -> int: return 41
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	print("FAIL burrow_capacity: ",message); quit(1)
func run() -> void:
	change_scene_to_file("res://scenes/lol2/jungle_walkthrough.tscn")
	for i in 1500:
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Not ready")
	scene.set_physics_process(false)
	var probe := TransactionProbe.new()
	scene.add_child(probe)
	if not probe.setup(scene).is_empty(): return fail("Probe setup failed")
	probe.set_process(false); probe.set_physics_process(false)
	var excluded := WorldCatalog.id_of(41)
	var full: Array = []
	for id in Catalog.ids("jungle"):
		if id != excluded and id != "jungle:kelsrick:Fine_Longsword" and full.size()<64: full.append(id)
	scene.carried_collected = full.duplicate()
	scene.equipped_item = ""; scene.equipped_armor = ""
	if full.size()!=64: return fail("Not full")
	var before: String = scene.quicksave("user://tests/burrow_capacity_before.json")
	if not before.is_empty(): return fail("Invalid initial save: "+before)
	var accepted := probe.collect()
	var after: String = scene.quicksave("user://tests/burrow_capacity_after.json")
	print("BURROW_RESULT accepted=",accepted," count=",scene.carried_collected.size()," history=",scene.world_items.history()," save_error=",after)
	if accepted or scene.carried_collected!=full or not after.is_empty() or 41 in scene.world_items.history().collected: return fail("Full refusal lost item/history/save")
	scene.carried_collected.pop_back()
	if not probe.collect(): return fail("Retry refused after freeing slot")
	if scene.carried_collected.size()!=64 or not excluded in scene.carried_collected or not 41 in scene.world_items.history().collected: return fail("Retry failed to commit once")
	if probe.items[41].visible: return fail("Taken sprite still visible")
	if not scene.quicksave("user://tests/burrow_capacity_retry.json").is_empty(): return fail("Retry save invalid")
	if probe.collect() or scene.carried_collected.size()!=64: return fail("Duplicate grant")
	print("PASS burrow_capacity_guard: full64 refusal preserves history/inventory/save; free slot allows one pickup, hidden sprite, valid save.")
	quit(0)
