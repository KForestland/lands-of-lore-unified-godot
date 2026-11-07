extends SceneTree
## Run only after museum_aloe_escape_test, in the same isolated profile.
## Missing producer output is a failure; no supplied pickup fallback.
const Aloe = preload("res://scripts/lol2/museum_aloe_state.gd")
const Arm = preload("res://scripts/lol2/museum_long_arm_state.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	printerr("FAIL earned Aloe restart: " + message)
	quit(1)
func run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var error: String = scene.quickload("user://tests/museum_aloe_escaped.json")
	if not error.is_empty(): fail(error); return
	if scene.aloe_pickups.state.taken != [true, true]: fail("pickup receipts"); return
	for i in 2:
		if scene.carried_collected.count(Aloe.IDS[i]) != 1 or scene.aloe_pickups.pickups[i].visible:
			fail("inventory or visibility for " + Aloe.IDS[i]); return
		if Aloe.IDS[i] in scene.item_effect_checkpoint.spent:
			fail("unconsumed route pickup marked spent"); return
	if int(scene.player_form) != 0 or scene.health <= 0 or absf(scene.player.global_position.y - 32.0) >= 4.0:
		fail("escaped player state"); return
	if scene.carried_collected.count(Arm.ITEM) != 1 or int(scene.long_arm.state.stage) <= 0 or scene.long_arm.pedestal.visible:
		fail("Long Arm reward/trap state"); return
	print("PASS fresh process restored Aloe escape: both pickups once, hidden actors, living human and Long Arm trap/reward preserved")
	quit()
