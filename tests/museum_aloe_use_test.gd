extends SceneTree
const S=preload("res://scripts/lol2/museum_aloe_state.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: printerr("FAIL: "+message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	scene.item_effects.set_process(false);scene.starting_magic.set_process(false)
	var owner=scene.aloe_pickups
	if not check(is_instance_valid(owner) and owner.pickups.size()==2,"Aloe actors"):return
	# Supplied collection receipts; real inventory/controller use and host persistence below.
	for i in 2:
		if not check(S.take(owner.state,scene.carried_collected,i),"Distinct Aloe grant"):return
	owner.present()
	if not check(scene.open_inventory(),"Open inventory"):return
	await process_frame
	var index:=-1
	for i in scene.inventory.item_list.item_count:
		if str(scene.inventory.item_list.get_item_metadata(i))==S.IDS[0]:index=i
	if not check(index>=0,"Inventory lists Aloe"):return
	scene.inventory.select_item(index)
	if not check(scene.inventory.use_button.visible and scene.inventory.use_button.text=="Use Aloe","Use Aloe action"):return
	scene.inventory.use_button.pressed.emit()
	await process_frame;await process_frame
	if not check(scene.item_effect_checkpoint.aloe.pending==5 and S.IDS[0] in scene.item_effect_checkpoint.spent and S.IDS[0] not in scene.carried_collected,"Shared native Aloe effect"):return
	if is_instance_valid(scene.inventory):scene.close_inventory()
	DirAccess.make_dir_recursive_absolute("user://tests")
	var path:="user://tests/museum_aloe_used.json"
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty(),"Consumed Aloe host save/load"):return
	if not check(not owner.pickups[0].visible and not owner.pickups[1].visible and scene.carried_collected.count(S.IDS[1])==1 and not S.take(owner.state,scene.carried_collected,0),"No respawn or duplicate"):return
	print("PASS supplied Museum Aloe pickup receipts -> production inventory Use Aloe +5 -> host save/load no respawn")
	quit()
