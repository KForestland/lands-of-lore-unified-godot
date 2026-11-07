extends SceneTree
const Catalog=preload("res://scripts/lol2/jungle_world_items_catalog.gd")
const ROWS=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 43, 44, 45, 46, 47, 48, 49, 73, 74, 75, 76, 77, 78, 79, 80, 81, 83, 84, 85, 86, 87]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok:printerr("FAIL Jungle missing: "+message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	var owner=scene.world_items
	if not check(owner!=null and owner.sprites.size()==74,"expected13 prior+61 new actors"):return
	for row in ROWS:
		if not check(owner.sprites.has(row) and owner.sprites[row].visible and not Catalog.id_of(row).is_empty(),"missing row "+str(row)):return
	# Supplied single carried receipt tests old-save migration; no earned-pickup claim.
	var id: String=Catalog.id_of(74)
	scene.carried_collected.append(id);owner.restore()
	if not check(not owner.sprites[74].visible and owner.history().collected.count(74)==1,"migration"):return
	DirAccess.make_dir_recursive_absolute("user://tests")
	var path:="user://tests/jungle_missing_items.json"
	var error: String=scene.quicksave(path)
	if not check(error.is_empty(),"save: "+error):return
	scene.carried_collected.erase(id)
	error=scene.quickload(path)
	if not check(error.is_empty(),"load: "+error):return
	if not check(not owner.sprites[74].visible and scene.carried_collected.count(id)==1 and owner.history().collected.count(74)==1,"restored one-shot pickup"):return
	for row in ROWS:
		var added: String=Catalog.id_of(row)
		if added not in scene.carried_collected:scene.carried_collected.append(added)
	owner.restore()
	if not check(scene.item_effects.equip_offhand(Catalog.id_of(15)) and preload("res://scripts/lol2/player_defense.gd").scalar(scene)==5,"Jungle Guard Shield equipment/defense"):return
	if not check(scene.quicksave(path).is_empty(),"all61 save"):return
	var saved: Dictionary=scene.Save.read_save(path).state
	var before: Dictionary=scene.area_handoff().duplicate(true)
	for invalid_rows in [[74,74],[82],[4.5],["4"]]:
		var bad: Dictionary=saved.duplicate(true)
		bad.quests.jungle_world_items.collected=invalid_rows
		if not check(not scene.apply_save(bad).is_empty() and scene.area_handoff()==before,"malformed history mutated host"):return
	var duplicate: Dictionary=saved.duplicate(true)
	duplicate.inventory.collected.append(id)
	if not check(not scene.apply_save(duplicate).is_empty() and scene.area_handoff()==before,"duplicate carried item admitted"):return
	if not check(scene.quickload(path).is_empty(),"all61 load"):return
	for row in ROWS:
		if not check(not owner.sprites[row].visible and scene.carried_collected.count(Catalog.id_of(row))==1 and owner.history().collected.count(row)==1,"all61 conservation"):return
	print("PASS 61 new Jungle actors,13 preserved; supplied61 migration/save/load, no respawn, five malformed packets rejected atomically")
	quit()
