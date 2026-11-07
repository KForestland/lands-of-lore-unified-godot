extends SceneTree
## Fresh process loads the file from museum_aloe_use_test (supplied pickup/consumption state).
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
	print("PASS fresh process Museum Aloe restore: consumed and carried hidden, pending heal and inventory preserved")
	quit()
