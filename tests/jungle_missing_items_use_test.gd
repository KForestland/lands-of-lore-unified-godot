extends "res://tests/jungle_missing_items_test.gd"
func run() -> void:
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	scene.item_effects.set_process(false);scene.starting_magic.set_process(false)
	var error: String=scene.quickload("user://tests/jungle_missing_items.json")
	if not check(error.is_empty(),"producer: "+error):return
	if not check(scene.open_inventory(),"open inventory"):return
	await process_frame
	for row in [2,78]:
		var id: String=Catalog.id_of(row)
		if not check(scene.item_effects.use(id),"consume row "+str(row)):return
		if not check(id not in scene.carried_collected and id in scene.item_effects.state().spent and row in scene.world_items.history().collected and not scene.world_items.sprites[row].visible and not scene.item_effects.use(id),"one-shot consumption"):return
	if not check(scene.item_effects.state().ancient_charges==1 and scene.item_effects.state().aloe.pending==5,"source effect state"):return
	scene.inventory.close();await process_frame
	var path:="user://tests/jungle_missing_items_used.json"
	error=scene.quicksave(path)
	if not check(error.is_empty(),"save: "+error):return
	var saved: Dictionary=scene.Save.read_save(path).state
	var before: Dictionary=scene.area_handoff().duplicate(true)
	for row in [2,78]:
		var bad: Dictionary=saved.duplicate(true)
		bad.quests.jungle_world_items.collected=bad.quests.jungle_world_items.collected.filter(func(value):return int(value)!=row)
		if not check(not scene.apply_save(bad).is_empty() and scene.area_handoff()==before,"consumption without receipt admitted"):return
	error=scene.quickload(path)
	if not check(error.is_empty(),"load: "+error):return
	for row in [2,78]:
		if not check(Catalog.id_of(row) not in scene.carried_collected and not scene.world_items.sprites[row].visible,"used item respawned"):return
	if not check(scene.item_effects.state().ancient_charges==1 and scene.item_effects.state().aloe.pending==5,"restored effect state"):return
	print("PASS new Jungle Stone/Aloe use, source effect state, no repeat/respawn, disk restore and atomic missing-receipt refusal; supplied pickup producer")
	quit()
