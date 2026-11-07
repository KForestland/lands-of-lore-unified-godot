extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete"
	root.add_child(scene);current_scene=scene
	await process_frame
	var error: String=scene.quickload("user://tests/mana_foil_used.json")
	if not error.is_empty():printerr("FAIL foil restart: "+error);quit(1);return
	for id in ["cave:control75:Mana_foil","jungle:magic_shop:Mana_foil"]:
		if id not in scene.item_effects.state().spent or id in scene.carried_collected:
			printerr("FAIL foil ownership after restart");quit(1);return
	if scene.starting_magic.magic_state().player.mana!=100:
		printerr("FAIL foil mana after restart");quit(1);return
	print("PASS fresh-process foil consumption and mana restored by actual Museum host")
	quit()
