extends SceneTree
const Ladder = preload("res://scripts/lol2/l8_cache_ladder.gd")
const Feet = preload("res://scripts/lol2/player_form_body.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func run() -> void:
	check(not Ladder.OP20_PLAYED and Ladder.CONTROL == 69, "opcode 20 stays unplayed")
	check(Ladder.validate(Ladder.initial(), {}).is_empty(), "initial ladder state")
	var bad: Dictionary = {"version": 1, "climbed": 1}
	check(not Ladder.validate(bad, {}).is_empty(), "a non-bool climb is refused")
	var scene: Node = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	for _i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not scene.ready_for_review or scene.get_node_or_null("L8CacheLadder") == null:
		check(false, "darker jungle ladder ready")
		await stop(scene, 1)
		return
	var ladder: Node = scene.get_node("L8CacheLadder")
	scene.player.position = Vector3(0, 32, 0)
	check(not ladder.use(), "a far E stays on the ground")
	scene.player.position = Vector3(-1076, 22, -2621)
	scene.flying = true
	check(not ladder.use(), "flying stays off the ladder")
	scene.flying = false
	var climbed: bool = ladder.use()
	var expected := Vector3(Ladder.DEST.x, Ladder.DEST.y + Feet.FOOT_OFFSET, Ladder.DEST.z)
	check(climbed and scene.player.position.is_equal_approx(expected), "owner point climbs to the opcode 18 ledge")
	check(bool(scene.quest_state.l8_cache_ladder.climbed), "the climb is saved")
	var again: Vector3 = scene.player.position
	check(ladder.use() and scene.player.position.is_equal_approx(again), "a second E stays on the ledge")
	check(preload("res://scripts/lol2/act_one_quest_state.gd").validate(scene.quest_state).is_empty(), "quest validate")
	if failures == 0: print("PASS l8 cache ladder: E at control 69 moves to the stored ledge")
	await stop(scene, 1 if failures else 0)
