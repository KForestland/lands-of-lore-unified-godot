extends SceneTree
const FOIL="cave:control75:Mana_foil"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave);current_scene=cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready:break
	if not cave.walkthrough_ready:
		printerr("FAIL Cave foil restart host readiness");quit(1);return
	cave.set_physics_process(false);cave.player.set_physics_process(false)
	cave.starting_magic.set_process(false);cave.item_effects.set_process(false)
	var error: String=cave._quickload("user://tests/mana_foil_cave.json")
	if not error.is_empty():
		printerr("FAIL Cave foil restart: "+error);quit(1);return
	if FOIL not in cave.stone_manafoil.collected or FOIL in cave.carried_items() or FOIL not in cave.item_effects.state().spent or cave.player_magic_checkpoint.player.mana!=60:
		printerr("FAIL Cave foil restart receipt, consumption or mana");quit(1);return
	cave.open_inventory()
	if cave.item_effects.use(FOIL):
		printerr("FAIL Cave foil restart allowed duplicate consumption");quit(1);return
	print("PASS fresh-process Cave foil receipt, spent state and mana restored; duplicate use refused")
	quit()
