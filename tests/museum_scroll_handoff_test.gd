extends SceneTree
## Loads museum_scroll_save_test supplied state, then transports actual Museum packet into Jungle.
## This verifies real host restore, not earned interaction or native spell effects.
const S = preload("res://scripts/lol2/museum_scroll_state.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete"
	root.add_child(scene);current_scene=scene
	await process_frame
	var error: String=scene.quickload("user://tests/museum_scroll_save.json")
	if not error.is_empty(): printerr("FAIL restart load: "+error);quit(1);return
	var owner=scene.scroll_pickups
	if owner.state.taken!=[true,true,false,false,false] or owner.state.consumed!=[true,false,false,false,false]:
		printerr("FAIL restart receipts");quit(1);return
	if scene.carried_collected.count(S.IDS[0])!=0 or scene.carried_collected.count(S.IDS[1])!=1:
		printerr("FAIL restart inventory");quit(1);return
	for i in 5:
		if owner.pickups[i].visible!=(i>=2): printerr("FAIL restart visibility");quit(1);return
	var packet: Dictionary=scene.inventory_state()
	if not preload("res://scripts/lol2/jungle_save.gd").validate_inventory(packet).is_empty(): printerr("FAIL outgoing packet");quit(1);return
	set_meta("lol2_jungle_handoff",packet)
	scene.free()
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	await process_frame
	if has_meta("lol2_jungle_handoff"): printerr("FAIL arrival rejected packet");quit(1);return
	if jungle.carried_collected.count(S.IDS[1])!=1 or S.IDS[0] in jungle.carried_collected: printerr("FAIL arrival scroll inventory");quit(1);return
	var path := "user://tests/museum_scroll_jungle.json"
	if not jungle.quicksave(path).is_empty() or not jungle.quickload(path).is_empty(): printerr("FAIL Jungle save/load");quit(1);return
	if jungle.carried_collected.count(S.IDS[1])!=1: printerr("FAIL Jungle reload copy");quit(1);return
	print("PASS supplied Museum scroll state -> real outgoing packet -> Jungle arrival -> Jungle save/load")
	quit()
