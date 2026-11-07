extends SceneTree
## Loads museum_aloe_use_test supplied collection plus production consumption, then actual Jungle packet.
## This verifies real host restore, not earned interaction or native spell effects.
const S = preload("res://scripts/lol2/museum_aloe_state.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete"
	root.add_child(scene);current_scene=scene
	await process_frame
	var error: String=scene.quickload("user://tests/museum_aloe_used.json")
	if not error.is_empty(): printerr("FAIL restart load: "+error);quit(1);return
	var owner=scene.aloe_pickups
	if owner.state.taken!=[true,true] or S.IDS[0] not in scene.item_effect_checkpoint.spent:
		printerr("FAIL restart receipts");quit(1);return
	if scene.carried_collected.count(S.IDS[0])!=0 or scene.carried_collected.count(S.IDS[1])!=1:
		printerr("FAIL restart inventory");quit(1);return
	for i in 2:
		if owner.pickups[i].visible: printerr("FAIL restart visibility");quit(1);return
	if scene.item_effect_checkpoint.aloe.pending!=5: printerr("FAIL pending heal lost");quit(1);return
	var packet: Dictionary=scene.inventory_state()
	if not preload("res://scripts/lol2/jungle_save.gd").validate_inventory(packet).is_empty(): printerr("FAIL outgoing packet");quit(1);return
	set_meta("lol2_jungle_handoff",packet)
	scene.free()
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	jungle.set_physics_process(false);jungle.player.set_physics_process(false)
	await process_frame
	jungle.item_effects.set_process(false);jungle.starting_magic.set_process(false)
	if has_meta("lol2_jungle_handoff"): printerr("FAIL arrival rejected packet");quit(1);return
	if jungle.carried_collected.count(S.IDS[1])!=1 or S.IDS[0] in jungle.carried_collected: printerr("FAIL arrival Aloe inventory");quit(1);return
	if S.IDS[0] not in jungle.item_effect_checkpoint.spent or jungle.item_effect_checkpoint.aloe.pending!=5: printerr("FAIL arrival consumption or heal");quit(1);return
	var path := "user://tests/museum_aloe_jungle.json"
	if not jungle.quicksave(path).is_empty() or not jungle.quickload(path).is_empty(): printerr("FAIL Jungle save/load");quit(1);return
	if jungle.carried_collected.count(S.IDS[1])!=1 or S.IDS[0] not in jungle.item_effect_checkpoint.spent or jungle.item_effect_checkpoint.aloe.pending!=5: printerr("FAIL Jungle reload inventory/effect");quit(1);return
	print("PASS supplied Museum Aloe receipts -> real Jungle handoff -> save/load retains carried copy, spent copy and pending heal")
	quit()
