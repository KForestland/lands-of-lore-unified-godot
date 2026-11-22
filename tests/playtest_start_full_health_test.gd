extends SceneTree
## BJ13 step 0 (owner 2026-11-10): only the F2 "End of Act 1 - Darker Jungle arrival" start gives Luther full health.
## The plain darker resume of the same file keeps the saved 19, and the pinned save file does not change.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const GATE := "res://scenes/lol2/original_game_gate.tscn"
const ID := "act1-end-darker-jungle"
var failures := 0
var exe := OS.get_environment("LOL2_ORIGINAL_GAME_EXE")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		print("FAIL: " + message)
	return condition

func _initialize() -> void: run.call_deferred()

func new_gate() -> Node:
	var gate = load(GATE).instantiate()
	gate.settings_path = "user://tests/playtest_full_health_%d.cfg" % Time.get_ticks_usec()
	root.add_child(gate)
	current_scene = gate
	await process_frame
	await process_frame
	gate.path_field.text = exe
	return gate

func leave(gate: Node) -> Node:
	for i in 600:
		await process_frame
		if current_scene != gate and current_scene != null: return current_scene
	return null

func run() -> void:
	if not check(not exe.is_empty() and FileAccess.file_exists(exe), "LOL2_ORIGINAL_GAME_EXE names the original LOLG.EXE"):
		quit(1); return
	var entry := {}
	for candidate in Starts.manifest().entries:
		if str(candidate.id) == ID: entry = candidate
	if not check(not entry.is_empty() and bool(entry.get("full_health", false)), "the darker start pins full_health"): quit(1); return
	var path := Starts.save_path(entry)
	var hash_before := FileAccess.get_sha256(path)
	check(hash_before == str(entry.sha256), "staged save matches its pin")
	# Through the F2 start: full health.
	var gate: Node = await new_gate()
	gate.start_playtest(ID)
	check(not gate.start_full_health, "the flag is cleared after the start")
	var scene: Node = await leave(gate)
	if not check(scene != null, "F2 start left the gate (status: %s)" % (gate.status.text if is_instance_valid(gate) else "freed")): quit(1); return
	for i in 5: await process_frame
	check(int(scene.starting_magic.health()) == 30, "F2 darker start arrives at 30 health (%s)" % scene.starting_magic.health())
	print("F2 start health ", scene.starting_magic.health())
	scene.queue_free(); current_scene = null
	for i in 3: await process_frame
	# The plain resume of the same file: unchanged.
	gate = await new_gate()
	var kept: String = gate.darker_save_path
	gate.darker_save_path = path
	gate._verify_and_start(false, false, false, true, false)
	gate.darker_save_path = kept
	scene = await leave(gate)
	if not check(scene != null, "plain resume left the gate"): quit(1); return
	for i in 5: await process_frame
	check(int(scene.starting_magic.health()) == 19, "plain darker resume keeps the saved 19 health (%s)" % scene.starting_magic.health())
	print("plain resume health ", scene.starting_magic.health())
	scene.queue_free(); current_scene = null
	for i in 3: await process_frame
	check(FileAccess.get_sha256(path) == hash_before, "the pinned save file is unchanged")
	if failures == 0: print("PASS F2 darker start: full health through the start list only; plain resume and the pinned save unchanged")
	quit(0 if failures == 0 else 1)
