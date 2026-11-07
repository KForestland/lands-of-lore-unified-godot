extends SceneTree
## Named checkpoint, rendered check (docs/dev-checkpoints.md). Run ONLY through
## `tools/dev_checkpoint.py run NAME --project COPY --script res://tests/dev_checkpoint_resume_test.gd`, which prepares a
## fresh isolated userdata with the hash-pinned save at the area's resume path and passes --dev-diagnostics and
## --original-game-exe. Here: the production original-game gate shows the area's Resume button; a real click on it
## loads the area through the production resume path; the live player state has no difference from the save file
## (mana may only regenerate, bounded by the measured simulated time since the click plus the save's carried
## regen_elapsed, and the live regeneration clock must agree); the F7 diagnostics panel reports the area; one screenshot.
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const MagicProgress = preload("res://scripts/lol2/hive_magic_reward.gd")
var failed := false
var clock_running := false
var simulated_seconds := 0.0
var last_frame_seconds := 0.0
func _process(delta: float) -> bool:
	if clock_running:
		last_frame_seconds = maxf(0.0, delta)
		simulated_seconds += last_frame_seconds
	return false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = at
		Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 2: await process_frame
func f7() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_F7; e.physical_keycode = KEY_F7; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 3: await process_frame
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null
func run() -> void:
	var receipt = JSON.parse_string(FileAccess.get_file_as_string("user://checkpoint.json"))
	if not check(receipt is Dictionary, "no user://checkpoint.json; run through tools/dev_checkpoint.py"): return
	if not check(OS.get_user_data_dir().get_file() == str(receipt.userdata).get_file(), "not running in the checkpoint's isolated userdata: %s" % OS.get_user_data_dir()): return
	var bytes := FileAccess.get_file_as_bytes(receipt.resume_path)
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
	if not check(ctx.finish().hex_encode() == receipt.sha256, "resume save hash differs"): return
	var saved = JSON.parse_string(bytes.get_string_from_utf8())
	var overlay = root.get_node_or_null("PlaytestLocation")
	if not check(overlay != null and overlay.diagnostics_enabled, "diagnostics not enabled (--dev-diagnostics)"): return
	var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
	root.add_child(gate); current_scene = gate
	for i in 6: await process_frame
	var button := find_button(gate, receipt.gate_button)
	if not check(button != null, "gate shows no '%s' button" % receipt.gate_button): return
	clock_running = true # every simulated second from the click on bounds the regeneration the area could have run
	await click(button)
	var area: Node = null
	for i in 1200:
		await process_frame
		var scene := current_scene
		if scene != null and scene != gate and is_instance_valid(scene) and scene.scene_file_path == receipt.scene and (scene.get("walkthrough_ready") == null or scene.walkthrough_ready):
			area = scene; break
	if not check(area != null, "'%s' did not reach %s (gate status: '%s')" % [receipt.gate_button, receipt.scene, gate.status.text if is_instance_valid(gate) else "gate freed"]): return
	for i in 10: await physics_frame
	var expected := Continuity.from_save(saved)
	var live := Continuity.from_host(area)
	# Mana: the save must carry the exact keys (no default maximum). Bound = measured simulated time since the click
	# (+2 frames, conservative) plus the save's carried remainder; a reset to full is accepted only if that much
	# regeneration time really passed.
	if not check(expected.get("magic.mana") is int and expected.get("magic.maximum") is int, "save lacks integer magic.mana/magic.maximum: %s/%s" % [expected.get("magic.mana"), expected.get("magic.maximum")]): return
	var saved_magic = saved.get("inventory", {}).get("magic", saved.get("quests", {}).get("player_magic_reward_state"))
	if not check(saved_magic is Dictionary, "save has no magic owner state"): return
	var period: float = MagicProgress.CAST_REGEN_SECONDS
	var remainder := float(saved_magic.get("regen_elapsed", 0.0))
	var elapsed := simulated_seconds + 2.0 * last_frame_seconds
	var mana: int = expected["magic.mana"]
	var maximum: int = expected["magic.maximum"]
	var allowed := {"magic.mana": Continuity.mana_allowance(mana, maximum, elapsed, remainder)}
	if mana == maximum: allowed = {} # nothing can regenerate: exact equality
	# Negative control on the same rule: a reset to full with no time elapsed must be rejected (the loader keeps the
	# carried remainder below one period, so it alone never completes a tick).
	if mana < maximum:
		var reset := expected.duplicate(); reset["magic.mana"] = maximum
		if not check(not Continuity.compare(expected, reset, {"magic.mana": Continuity.mana_allowance(mana, maximum, 0.0, remainder)}).is_empty(), "negative control: zero-time reset to full mana was accepted"): return
	var reset_distinguishable := mana < maximum and elapsed + remainder < float(maximum - mana) * period
	# The live regeneration clock must agree with the mana it reports.
	var live_magic: Dictionary = area.starting_magic.magic_state()
	var live_mana := int(live_magic.player.mana)
	var live_regen := float(live_magic.get("regen_elapsed", 0.0))
	if not check(is_finite(live_regen) and live_regen >= 0.0 and live_regen < period, "live regen_elapsed invalid: %s" % live_regen): return
	if live_mana < maximum:
		var advanced := float(live_mana - mana) * period + live_regen - remainder
		if not check(advanced >= -0.001 and advanced <= elapsed + 0.001, "regeneration clock advanced %.6f s, measured %.6f s (mana %d->%d, regen %.6f->%.6f)" % [advanced, elapsed, mana, live_mana, remainder, live_regen]): return
	else:
		if not check(live_regen == 0.0, "full mana with a running regen clock %.6f" % live_regen): return
	var errors := Continuity.compare(expected, live, allowed)
	if not check(errors.is_empty(), "loaded state differs from the checkpoint save: %s" % [errors]): return
	await f7()
	var report: Dictionary = overlay.report
	if not check(overlay.panel_open() and report.status == "ready" and report.area == receipt.area, "diagnostics panel: %s" % [report]): return
	var image := root.get_texture().get_image()
	var shot := "user://checkpoint_%s.png" % receipt.checkpoint
	image.save_png(shot)
	await f7()
	print("MANA %d/%d -> %d (regen %.6f -> %.6f) measured %.6f s since click; allowed %s; reset-to-full distinguishable at this elapsed: %s" % [mana, maximum, live_mana, remainder, live_regen, elapsed, allowed.get("magic.mana", "exact"), reset_distinguishable])
	print("PASS dev_checkpoint_resume: %s (%s, %s) — gate '%s' click loaded %s with no player-state difference from the save (%d fields); diagnostics ready; screenshot %s" % [receipt.checkpoint, receipt.area, receipt.provenance.kind, receipt.gate_button, receipt.scene, expected.size(), ProjectSettings.globalize_path(shot)])
	quit()
