extends SceneTree
const FOIL="cave:control75:Mana_foil"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok: printerr("FAIL cave foil: "+message);quit(1)
	return ok
func run() -> void:
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave);current_scene=cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready:break
	if not check(cave.walkthrough_ready and cave.stone_manafoil!=null,"host ready"):return
	cave.set_physics_process(false);cave.player.set_physics_process(false)
	cave.item_effects.set_process(false);cave.starting_magic.set_process(false)
	# Supplied pickup receipt; this does not qualify the earned control75 route.
	cave.stone_manafoil.restore([FOIL])
	var magic: Dictionary=cave.starting_magic.magic_state().duplicate(true)
	magic.player.maximum=100;magic.player.mana=10;cave.starting_magic.commit(magic)
	if not check(cave.open_inventory(),"inventory open"):return
	await process_frame
	if not check(cave.item_effects.use(FOIL),"use"):return
	if not check(FOIL in cave.stone_manafoil.collected and FOIL not in cave.carried_items() and cave.player_magic_checkpoint.player.mana==60,"receipt and mana"):return
	DirAccess.make_dir_recursive_absolute("user://tests")
	var path:="user://tests/mana_foil_cave.json"
	var error: String=cave._quicksave(path)
	if not check(error.is_empty(),"save: "+error):return
	error=cave._quickload(path)
	if not check(error.is_empty(),"load: "+error):return
	if not check(FOIL in cave.stone_manafoil.collected and FOIL not in cave.carried_items() and FOIL in cave.item_effects.state().spent and cave.player_magic_checkpoint.player.mana==60,"restored receipt and mana"):return
	var bad: Dictionary=cave._save_state()
	bad.stone_manafoil=[]
	if not check(not cave.WalkthroughSave.validate(bad,cave._checkpoint_count()).is_empty(),"spent without pickup admitted"):return
	set_meta("lol2_cave_completion",cave._completion_state())
	cave.queue_free();await process_frame;await process_frame
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete"
	root.add_child(museum);current_scene=museum
	await process_frame
	museum.set_physics_process(false);museum.starting_magic.set_process(false)
	if not check(FOIL not in museum.carried_collected and FOIL in museum.item_effects.state().spent and museum.player_magic_checkpoint.player.mana==60,"Museum transfer"):return
	print("PASS Cave foil supplied pickup: consume, preserve receipt, save/load, reject missing receipt, Museum transfer")
	quit()
