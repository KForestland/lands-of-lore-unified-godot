extends SceneTree
## Fresh process loads the file from museum_scroll_save_test (supplied pickup/consumption state).
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
	print("PASS fresh process Museum scroll host restore: consumed hidden, carried hidden, three uncollected visible")
	quit()
