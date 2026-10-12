extends SceneTree
## Development diagnostics, headless component checks (docs/dev-diagnostics.md). The four-host rendered acceptance
## (real hosts, actual fields, early refusal, capture changes no canonical state, clipboard) is
## dev_diagnostics_hosts_test. Here: every changed script compiles; no scene / unsupported scenes are
## reported without reading host state; host kinds include subclasses; record() returns the error unchanged; the F7 panel
## needs the opt-in, captures on open, restores the previous pause state, and does not touch the clipboard on open.
const Diagnostics = preload("res://scripts/lol2/dev_diagnostics.gd")
const CHANGED := ["res://scripts/lol2/dev_diagnostics.gd", "res://scripts/lol2/playtest_location.gd", "res://scripts/lol2/cave_walkthrough.gd",
	"res://scripts/lol2/museum_walkthrough.gd", "res://scripts/lol2/jungle_walkthrough.gd", "res://scripts/lol2/hive_review.gd"]
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
	await process_frame
func run() -> void:
	for path in CHANGED:
		var script = load(path)
		if not check(script is GDScript and script.can_instantiate(), "%s does not compile" % path): return
	var none := Diagnostics.capture(null)
	if not check(none.status == "no scene" and none.player.is_empty(), "no scene: %s" % [none]): return
	var plain := Node3D.new(); plain.name = "Plain"
	root.add_child(plain)
	var unsupported := Diagnostics.capture(plain)
	if not check(unsupported.status == "unsupported" and unsupported.player.is_empty() and unsupported.quests.is_empty(), "unsupported: %s" % [unsupported]): return
	# Host kinds, including subclasses (the not-ready "loading" case is checked on real hosts in the rendered test).
	var kinds := {"res://scripts/lol2/cave_walkthrough.gd": "Cave", "res://scripts/lol2/cave_encounter.gd": "Cave", "res://scripts/lol2/museum_walkthrough.gd": "Museum",
		"res://scripts/lol2/jungle_walkthrough.gd": "Jungle", "res://scripts/lol2/darker_jungle.gd": "Jungle", "res://scripts/lol2/hive_review.gd": "Hive"}
	for path in kinds:
		var kind := Diagnostics.script_kind(load(path))
		if not check(kind == kinds[path], "%s kind '%s'" % [path, kind]): return
	if not check(Diagnostics.script_kind(load("res://scripts/lol2/playtest_location.gd")).is_empty(), "non-host script got a kind"): return
	# Observed vitals keep zero/death visible (the Hive travel packet omits health at 0); unknown when there is no owner.
	var zero := Diagnostics.vitals_from(0, "Warriors.health")
	var alive := Diagnostics.vitals_from(12, "health")
	var drowned := Diagnostics.vitals_from(30, "roach.model.player_health", true)
	var none_owner := Diagnostics.vitals_from(null, "no cave combat (roach)")
	if not check(zero.health == 0 and zero.status == "dead" and alive.health == 12 and alive.status == "alive" and drowned.status == "dead" and none_owner.status == "unknown" and none_owner.health == null, "vitals: %s %s %s %s" % [zero, alive, drowned, none_owner]): return
	var vitals_text := Diagnostics.format({"area": "Hive", "status": "ready", "location": {}, "vitals": zero, "player": {}, "quests": {}, "last_operation": {}, "route_error": ""})
	if not check("Vitals: health 0, dead (Warriors.health)" in vitals_text, "vitals line: %s" % vitals_text): return
	# Displayed locals are bounded and the omission is counted.
	var many := {}
	for i in Diagnostics.MAX_LOCALS + 5: many["Local_%02d" % i] = i
	var shown := Diagnostics.bounded(many, "monastery.", Diagnostics.MAX_LOCALS)
	var few := Diagnostics.bounded({"Left_Village": 2, "Met_Dawn": 1}, "monastery.", Diagnostics.MAX_LOCALS)
	if not check(shown.size() == Diagnostics.MAX_LOCALS + 1 and shown["monastery.truncated"] == 5 and shown.has("monastery.Local_00") and not shown.has("monastery.Local_%02d" % (Diagnostics.MAX_LOCALS + 4)), "bounded locals: %s" % [shown]): return
	if not check(few == {"monastery.Left_Village": 2, "monastery.Met_Dawn": 1} and Diagnostics.bounded(null, "x.", 3).is_empty(), "small/invalid locals: %s" % [few]): return
	# record() returns its error unchanged and keeps the last outcome.
	if not check(Diagnostics.record(plain, "save", "Close the current overlay before saving.") == "Close the current overlay before saving.", "record changed the error"): return
	var op: Dictionary = Diagnostics.last_operation
	if not check(op.operation == "save" and op.outcome == "refused" and op.area == "unknown" and op.reason == "Close the current overlay before saving.", "last operation %s" % [op]): return
	if not check(Diagnostics.record(plain, "load", "") == "" and Diagnostics.last_operation.outcome == "ok", "ok outcome"): return
	var text := Diagnostics.format(Diagnostics.capture(plain))
	if not check(text.begins_with("LoL2 diagnostics | Plain | unsupported") and "Last operation: load ok in unknown" in text and not "/home/" in text, "format: %s" % text): return
	# format() is deterministic: the same captured report formats identically later (the age is fixed at capture).
	Diagnostics.record(plain, "save", "Close the current overlay before saving.")
	var captured := Diagnostics.capture(plain)
	var first := Diagnostics.format(captured)
	await create_timer(0.3).timeout
	if not check(Diagnostics.format(captured) == first, "format changed over time:\n%s\n---\n%s" % [first, Diagnostics.format(captured)]): return
	# Panel: opt-in, F7 open/close, pause restored, no clipboard write on open.
	var overlay = root.get_node_or_null("PlaytestLocation")
	if not check(overlay != null and not overlay.diagnostics_enabled, "overlay missing or enabled without opt-in"): return
	await key(KEY_F7)
	if not check(not overlay.panel_open() and not paused, "F7 acted without the opt-in"): return
	overlay.diagnostics_enabled = true
	var clipboard := DisplayServer.get_name() != "headless"
	if clipboard: DisplayServer.clipboard_set("sentinel")
	for prior in [false, true]:
		paused = prior
		await key(KEY_F7)
		if not check(overlay.panel_open() and paused and overlay.report_text.begins_with("LoL2 diagnostics"), "F7 did not open (prior paused %s)" % prior): return
		if not check(not clipboard or DisplayServer.clipboard_get() == "sentinel", "opening wrote the clipboard"): return
		await key(KEY_F7)
		if not check(not overlay.panel_open() and paused == prior, "close did not restore pause %s" % prior): return
	paused = false
	plain.queue_free()
	print("PASS dev_diagnostics: %d changed scripts compile; no-scene/unsupported reported without reading host state; 6 host kinds incl. subclasses; zero/dead/unknown vitals shown; locals bounded with a truncation count; record() passes errors through; format deterministic for a captured report; F7 panel needs opt-in, captures on open and restores prior pause (false and true)." % CHANGED.size())
	quit()
