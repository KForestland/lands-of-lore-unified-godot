extends SceneTree
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	if not check(scene.walkthrough_ready,"Cave initialization failed"):return
	scene.set_physics_process(false)
	var path:="user://tests/cave_roach_population.json"
	State.first_contact(scene.roach_population,1140)
	var contracts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cave_roach_ai_choice_native.json")).contracts
	var goal=preload("res://scripts/lol2/hive_ai_goal_choice.gd").new()
	var action=preload("res://scripts/lol2/hive_ai_action_choice.gd").new()
	if not check(goal.configure(contracts.goals).is_empty() and action.configure(contracts.actions).is_empty(),"Roach profile configuration failed"):return
	var selected:=State.choose_pending(scene.roach_population,"25",scene.roach_population.actors["25"].stats,goal,action)
	if not check(not selected.has("error") and selected.chosen and scene.roach_population.actors["25"].a9==6 and scene.roach_population.actors["25"].ab==0,"Source-scored population decision failed"):return
	scene.roach_population.actors["25"].position[0]+=17
	var before: Dictionary=scene.roach_population.duplicate(true)
	if not check(scene._quicksave(path).is_empty(),"Population save failed"):return
	State.commit(scene.roach_population,"25",1)
	if not check(scene._quickload(path).is_empty() and scene.roach_population==before,"Pending decision disk rollback failed"):return
	scene.set_physics_process(false)
	var saved: Dictionary=scene._save_state()
	var bad:=saved.duplicate(true)
	bad.roach_population.actors["25"].health=0
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	if not check(not scene._quickload(path).is_empty() and scene.roach_population==before,"Malformed population changed scene"):return
	bad=saved.duplicate(true);bad.erase("roach_population")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	if not check(not scene._quickload(path).is_empty(),"Missing marked population accepted"):return
	bad.erase("roach_population_schema")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	var legacy_initial:=State.initial();State.initialize_visuals(legacy_initial);State.initialize_live(legacy_initial)
	if not check(scene._quickload(path).is_empty() and scene.roach_population==legacy_initial,"Legacy cave migration failed"):return
	print("PASS: cave scene persists23 Roach identities, pending decisions/positions, rollback, malformed/missing rejection and legacy migration")
	scene.queue_free()
	await process_frame
	quit()
