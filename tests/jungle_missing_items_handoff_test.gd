extends "res://tests/jungle_missing_items_test.gd"
func dispose(scene) -> void:
	scene.queue_free();await process_frame;await process_frame
func run() -> void:
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	await process_frame
	jungle.set_physics_process(false);jungle.player.set_physics_process(false)
	var error: String=jungle.quickload("user://tests/jungle_missing_items.json")
	if not check(error.is_empty(),"producer save: "+error):return
	var transfer: Dictionary=jungle.area_handoff()
	await dispose(jungle)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive);current_scene=hive
	await process_frame
	hive.set_physics_process(false);hive.player.set_physics_process(false)
	error=hive.apply_area_handoff(transfer)
	if not check(error.is_empty(),"Hive import: "+error):return
	if not check(preload("res://scripts/lol2/player_defense.gd").scalar(hive)==5,"Hive shield defense"):return
	for row in ROWS:
		if not check(hive.item_effects.carried().count(Catalog.id_of(row))==1,"Hive inventory conservation"):return
	error=hive.quicksave("user://tests/jungle_missing_items_hive.json")
	if not check(error.is_empty(),"Hive save: "+error):return
	error=hive.quickload("user://tests/jungle_missing_items_hive.json")
	if not check(error.is_empty(),"Hive load: "+error):return
	transfer=hive.area_handoff()
	await dispose(hive)
	jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	await process_frame
	jungle.set_physics_process(false);jungle.player.set_physics_process(false)
	error=jungle.apply_area_handoff(transfer)
	if not check(error.is_empty(),"Jungle return: "+error):return
	for row in ROWS:
		if not check(jungle.carried_collected.count(Catalog.id_of(row))==1 and not jungle.world_items.sprites[row].visible and jungle.world_items.history().collected.count(row)==1,"returned pickup conservation"):return
	if not check(preload("res://scripts/lol2/player_defense.gd").scalar(jungle)==5,"returned shield defense"):return
	print("PASS supplied61 pickups Jungle->Hive save/load->Jungle, no duplicates/respawns and equipped shield defense5")
	quit()
