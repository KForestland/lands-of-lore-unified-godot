extends SceneTree
## HIVE-FLUTE-SUMMON (owner 10-26-06 at F10 X -2352 Y -7609 H -203; Prima p.77): the flute played on the pit lip next to the
## lift shaft summons the lift even when the player never crossed native trigger 282 in the hall; another storey's floor
## at the same x/z (region 234, floor -57) does not arm it.
const State = preload("res://scripts/lol2/hive_elevator_state.gd")
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error("FAIL: " + message)
	quit(1)
	return false
func _run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	var lift = scene.elevator
	lift.set_physics_process(false)
	lift.checkpoint = State.initial()
	lift.previous_trigger = -1
	scene.player.position = Vector3(-2352.037, -202.95, -7609.46)
	if not check(lift.trigger_at_player() == 282, "the owner's pit-lip point arms the summon"): return
	lift._physics_process(1.0 / 60.0)
	if not check(lift.checkpoint.armed, "standing on the pit lip arms the lift"): return
	if not check(State.play_flute(lift.checkpoint), "the flute can be played there"): return
	if not check(State.advance(lift.checkpoint, 1.0) and lift.checkpoint.played_flute and lift.checkpoint.target == 0, "the lift is summoned"): return
	scene.player.position = Vector3(-2352.037, -25.0, -7609.46)
	if not check(lift.trigger_at_player() == -1, "the storey above (region 234, floor -57) does not arm it"): return
	print("PASS hive_flute_pit_lip")
	quit(0)
