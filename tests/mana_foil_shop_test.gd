extends SceneTree
const State=preload("res://scripts/lol2/magic_shop_state.gd")
const FOIL="jungle:magic_shop:Mana_foil"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok: printerr("FAIL shop foil: "+message);quit(1)
	return ok
func settle(shop) -> bool:
	for i in 1500:
		if not State.active(shop.state()):return true
		shop.advance(0.1)
	return false
func run() -> void:
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var shop=scene.magic_shop
	shop.set_process(false);scene.monastery.set_process(false);scene.weapon_shop.set_process(false)
	# Room entry supplied; original room sequence and visible sprite click grant the foil.
	if not check(shop.enter_room() and settle(shop),"room introduction"):return
	shop.leave_room()
	if not check(shop.enter_room() and settle(shop),"return greeting"):return
	if not check(shop.offer_item("") and settle(shop),"offer conversation"):return
	var p: Array=shop.Shop.SPRITES[1]
	if not check(shop.sprite_nodes[1].visible and shop.click(Vector2i(p[0]+1,p[1]+1)),"foil sprite click"):return
	if not check(FOIL in scene.carried_collected and shop.state().flags["50"]==1 and settle(shop),"grant and receipt"):return
	shop.leave_room();scene.set_physics_process(false)
	var magic: Dictionary=scene.starting_magic.magic_state().duplicate(true)
	magic.player.maximum=100;magic.player.mana=10;scene.starting_magic.commit(magic)
	if not check(scene.open_inventory(),"inventory"):return
	await process_frame
	if not check(scene.item_effects.use(FOIL),"consume"):return
	scene.inventory.close();await process_frame
	if not check(scene.starting_magic.magic_state().player.mana==60 and FOIL not in scene.carried_collected and FOIL in scene.item_effects.state().spent,"effect"):return
	DirAccess.make_dir_recursive_absolute("user://tests")
	var path:="user://tests/mana_foil_shop.json"
	var error: String=scene.quicksave(path)
	if not check(error.is_empty(),"save: "+error):return
	error=scene.quickload(path)
	if not check(error.is_empty(),"load: "+error):return
	if not check(scene.starting_magic.magic_state().player.mana==60 and FOIL not in scene.carried_collected and FOIL in scene.item_effects.state().spent,"restored consumption"):return
	if not check(shop.enter_room() and settle(shop) and not shop.sprite_nodes[1].visible,"consumed pickup respawned"):return
	shop.leave_room()
	var transfer: Dictionary=scene.area_handoff()
	if not check(scene.Save.validate_inventory(transfer.inventory).is_empty(),"travel inventory rejected"):return
	scene.queue_free();await process_frame;await process_frame
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive);current_scene=hive
	await process_frame
	hive.starting_magic.set_process(false);hive.item_effects.set_process(false)
	hive.set_physics_process(false)
	if not check(hive.apply_area_handoff(transfer).is_empty(),"Hive handoff rejected"):return
	if not check(hive.player_magic_checkpoint.player.mana==60 and FOIL in hive.item_effects.state().spent and FOIL not in hive.item_effects.carried(),"Hive lost consumption or mana"):return
	print("PASS shop foil: original sprite grant, one-shot receipt, consumption, Jungle save/load, no respawn and Hive transfer; supplied room entry and mana")
	quit()
