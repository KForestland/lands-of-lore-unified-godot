extends SceneTree
const IDS=["cave:control75:Mana_foil","jungle:magic_shop:Mana_foil"]
var scene
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok: printerr("FAIL foil: "+message);quit(1)
	return ok
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete"
	root.add_child(scene);current_scene=scene
	await process_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	scene.item_effects.set_process(false);scene.starting_magic.set_process(false)
	# Supplied carried items from prior areas; actual inventory UI/controller and host save below.
	for id in IDS: scene.carried_collected.append(id)
	var magic: Dictionary=scene.starting_magic.magic_state().duplicate(true)
	magic.player.maximum=100;magic.player.mana=10
	scene.starting_magic.commit(magic)
	scene.player_form=1
	if not check(not scene.item_effects.use(IDS[0]),"transformed use admitted"):return
	scene.player_form=0
	for i in 2:
		if i==1:
			magic=scene.starting_magic.magic_state().duplicate(true)
			magic.player.mana=100;scene.starting_magic.commit(magic)
		if not check(scene.open_inventory(),"inventory open"):return
		await process_frame
		var index:=-1
		for j in scene.inventory.item_list.item_count:
			if str(scene.inventory.item_list.get_item_metadata(j))==IDS[i]:index=j
		if not check(index>=0,"foil missing"):return
		scene.inventory.select_item(index)
		if not check(scene.inventory.use_button.visible and scene.inventory.use_button.text=="Use Mana Foil","use button"):return
		scene.inventory.use_button.pressed.emit()
		await process_frame
		if not check(scene.starting_magic.magic_state().player.mana==(60 if i==0 else 100),"mana result"):return
		if not check(IDS[i] in scene.item_effects.state().spent and IDS[i] not in scene.carried_collected and not scene.item_effects.use(IDS[i]),"consumption/repeat"):return
		if is_instance_valid(scene.inventory):scene.close_inventory()
	DirAccess.make_dir_recursive_absolute("user://tests")
	var path:="user://tests/mana_foil_used.json"
	var error: String=scene.quicksave(path)
	if not check(error.is_empty(),"save: "+error):return
	error=scene.quickload(path)
	if not check(error.is_empty(),"load: "+error):return
	for id in IDS:
		if not check(id in scene.item_effects.state().spent and id not in scene.carried_collected,"restored ownership"):return
	if not check(scene.starting_magic.magic_state().player.mana==100,"restored mana"):return
	print("PASS both foil IDs via inventory UI: +50, consume at cap, form/repeat refusal, Museum save/load; supplied items")
	quit()
