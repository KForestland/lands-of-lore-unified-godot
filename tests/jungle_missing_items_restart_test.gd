extends "res://tests/jungle_missing_items_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	var error: String=scene.quickload("user://tests/jungle_missing_items.json")
	if not check(error.is_empty(),"fresh restart: "+error):return
	if not check(scene.item_effects.state().get("offhand")==Catalog.id_of(15) and preload("res://scripts/lol2/player_defense.gd").scalar(scene)==5,"restarted Guard Shield defense"):return
	for row in ROWS:
		if not check(not scene.world_items.sprites[row].visible and scene.carried_collected.count(Catalog.id_of(row))==1 and scene.world_items.history().collected.count(row)==1,"fresh restart conservation"):return
	print("PASS fresh-process61 Jungle pickups restored once with actors hidden")
	quit()
