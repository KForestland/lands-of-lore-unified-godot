extends SceneTree
## Rix (L7 actor57) in Dark Halls with the earned R18 monastery quests (LOL2_EARNED_SAVES): present and hostile; his
## death applies source group 14414 once (soul -1, GV_RIX_DEAD = 1, so the cellar no longer shows him); E on his body
## gives the Plasma staff (group 14496) once; state and staff survive quicksave/quickload.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Monastery = preload("res://scripts/lol2/monastery_quest_state.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dark_halls_rix: ", message); quit(1); return false
func press_e() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_E; e.physical_keycode = KEY_E; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
func run() -> void:
	var saves := OS.get_environment("LOL2_EARNED_SAVES")
	if saves.is_empty(): return fail("LOL2_EARNED_SAVES is required")
	var earned := Save.read_save(saves + "/act1_broken_repaired_monastery.json")
	if not str(earned.error).is_empty(): return fail("Earned save: " + str(earned.error))
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Dark Halls not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var error: String = scene.apply_area_handoff({"inventory": earned.state.inventory, "quests": earned.state.quests})
	if not error.is_empty(): return fail("Earned handoff: " + error)
	var pop = scene.creatures
	pop.set_physics_process(false); pop.set_process(false)
	if not pop.bodies.has("57") or int(pop.state.actors["57"].health) != 200: return fail("Rix not present with 200 health")
	var soul := int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL)
	if int(scene.quest_state.monastery.globals.get("GV_RIX_DEAD", 0)) != 0: return fail("Rix already dead in the earned save")
	pop.receive_damage("57", 999, false)
	for i in 3: await physics_frame
	if not bool(scene.rix.state().dead): return fail("Rix death not applied")
	var globals: Dictionary = scene.quest_state.monastery.globals
	if int(globals.GV_LUTHERS_SOUL) != soul - 1 or int(globals.GV_RIX_DEAD) != 1: return fail("Death group: soul %d -> %d, dead %s" % [soul, int(globals.GV_LUTHERS_SOUL), globals.GV_RIX_DEAD])
	for i in 3: await physics_frame
	if int(globals.GV_LUTHERS_SOUL) != soul - 1: return fail("Death group ran twice")
	if Monastery.side_actor_present(scene.quest_state.monastery, "MCEL"): return fail("The cellar would still show Rix")
	scene.set_physics_process(false)
	var body: Vector3 = pop.bodies["57"].global_position
	scene.player.global_position = body + Vector3(60, 34, 0); scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(body + Vector3(0, 20, 0))
	await physics_frame
	await press_e()
	var staff: String = scene.rix.rix.corpse.id
	if not staff in scene.carried_collected or not bool(scene.rix.state().staff): return fail("E on Rix's body gave no staff")
	var count: int = scene.carried_collected.size()
	await press_e()
	if scene.carried_collected.size() != count: return fail("Second E gave more")
	if not preload("res://scripts/lol2/item_catalog.gd").admitted(staff, "jungle") or preload("res://scripts/lol2/item_catalog.gd").slot(staff) != "weapon": return fail("Plasma staff not a catalog weapon")
	var path := "user://tests/dark_halls_rix.json"
	if not scene.quicksave(path).is_empty(): return fail("Quicksave failed")
	var saved := Save.read_save(path, preload("res://scripts/lol2/dark_halls.gd").FORMAT)
	if not str(saved.error).is_empty(): return fail("Read save: " + str(saved.error))
	scene.quest_state.dark_halls_rix = {"dead": false, "staff": false}
	error = scene.apply_save(saved.state)
	if not error.is_empty() or not bool(scene.rix.state().staff) or int(scene.creatures.state.actors["57"].health) != 0 or int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL) != soul - 1: return fail("Reload lost Rix's death/staff: %s" % error)
	print("PASS dark_halls_rix: earned quests, Rix present (200), death group once (soul %d -> %d, GV_RIX_DEAD 1, cellar empty), Plasma staff once from his body, kept across quicksave/quickload" % [soul, soul - 1])
	quit(0)
