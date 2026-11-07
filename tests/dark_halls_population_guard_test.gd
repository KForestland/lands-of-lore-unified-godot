extends SceneTree
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Halls = preload("res://scripts/lol2/dark_halls.gd")
const State = preload("res://scripts/lol2/scripted_creature_state.gd")
const INPUT := "res://tests/fixtures/"
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	print("FAIL population_guard: ",message);quit(1)
func snapshot(scene) -> String:
	return JSON.stringify({"quests":scene.quest_state,"inventory":scene.inventory_state(),"population":scene.creatures.checkpoint(),"position":scene.player.position})
func run() -> void:
	var valid := Save.read_save(INPUT+"k2_valid.json",Halls.FORMAT)
	if not valid.error.is_empty(): return fail("Valid baseline refused: "+valid.error)
	var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT+"k2_invalid.json"))
	var src := State.source("res://scripts/lol2/dark_halls_population_source.json")
	if State.validate(bad.quests.dark_halls_population,src).is_empty(): return fail("Corruption fixture not invalid")
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in 1500:
		await process_frame
		if current_scene!=null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene==null or not scene.get("ready_for_review"): return fail("Not ready")
	scene.set_physics_process(false);scene.creatures.set_physics_process(false);scene.creatures.set_process(false)
	var before := snapshot(scene)
	var read_bad := Save.read_save(INPUT+"k2_invalid.json",Halls.FORMAT)
	var apply_error: String = scene.apply_save(bad)
	var unchanged := snapshot(scene)==before
	print("POPULATION_RESULT read_error=",read_bad.error," apply_error=",apply_error," unchanged=",unchanged)
	if read_bad.error.is_empty() or apply_error.is_empty() or not unchanged: return fail("Malformed packet not rejected before mutation")
	var handoff_error: String = scene.apply_area_handoff({"inventory":bad.inventory,"quests":bad.quests})
	if handoff_error.is_empty() or snapshot(scene)!=before: return fail("Malformed handoff not rejected atomically")
	if not scene.apply_save(valid.state).is_empty() or int(scene.creatures.state.actors["55"].health)!=0: return fail("Valid dead actor not restored")
	var legacy: Dictionary = valid.state.duplicate(true);legacy.quests.erase("dark_halls_population")
	if not Save.validate(legacy,Halls.FORMAT).is_empty(): return fail("Legacy packet missing population refused")
	print("PASS population_guard: malformed disk/save/handoff rejected before mutation; valid dead actor restores; legacy omission remains admitted.")
	quit(0)
