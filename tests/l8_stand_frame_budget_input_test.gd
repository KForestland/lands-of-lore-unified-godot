extends SceneTree
## Frame budget at the owner's own Darker Jungle stand, on the ORDINARY clock (registry needs.clock = "ordinary": the runner
## leaves out --fixed-fps 60). Owner r19p/r19p2 2026-11-17 (F10 14-47-31 at -4287, 1183: 'the framerate goes down',
## 'shaking and slow frame rate'). Measured 2026-11-18 on this machine's Xvfb (1280x720, gl_compatibility): r19p 172 ms a
## frame, r19p2 83 ms; each 60 Hz physics step cost 11 ms of game script (r19p 17 ms), so the clock fell behind and ran ~5
## steps a frame (r19p: the 8-step cap). The creature step called player_defense.scalar() for each of his 97 L8 creatures.
## Resumes his own save (local only: tmp/l8_perf_inputs, OWNER_DERIVED.md), stands still at his pose for 12 s with slow
## mouse turns, and measures (a) the wall time of each frame and (b) the game's script time in each physics step
## (bracketed by nodes at the lowest and highest physics priorities). Rendering on Xvfb is software; a real GPU is faster,
## so the frame budget is for this gate host. Fails when a mean or the worst goes over its budget.
const GameSave = preload("res://scripts/lol2/game_save.gd")
const SAVE := "res://tmp/l8_perf_inputs/owner_144731.json"
const SAVE_SHA := "8d7f48ea36d5b44d0b56ddc539b9ed16f69c034f41057a2bd496f91655075e0b"
const STAND_MS := 12000
## Budgets for this machine's Xvfb gate (2026-11-18, two runs each on r19p3 17ec1001 with and without the fix):
## r19p3 frame mean 82.9/85.0, p95 96/101, step mean 11.1/11.2, worst 15.3/15.5 -> FAIL; fixed frame mean 23.8/24.1,
## p95 41.7/41.5, step mean 4.71/4.73, worst 6.95/6.86 -> PASS. A different gate host needs its own numbers.
const FRAME_MEAN_BUDGET_MS := 35.0
const FRAME_P95_BUDGET_MS := 60.0
const STEP_MEAN_BUDGET_MS := 6.5
const STEP_WORST_BUDGET_MS := 10.0

class Bracket extends Node:
	var first := true
	var log: Array
	func _init(is_first: bool, into: Array) -> void:
		first = is_first; log = into
		process_physics_priority = -1000000 if first else 1000000
	func _physics_process(_d: float) -> void: log.append([first, Time.get_ticks_usec()])

var marks: Array = []
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error("FAIL l8_stand_frame_budget_input: " + message); quit(1)
func stats(xs: Array) -> Dictionary:
	var s := xs.duplicate(); s.sort()
	var t := 0.0
	for x in s: t += x
	return {"mean": t / s.size(), "p50": s[s.size() / 2], "p95": s[int(s.size() * 0.95)], "worst": s[-1]}

func run() -> void:
	if DisplayServer.get_name() == "headless" or Engine.time_scale != 1.0: return fail("rendered ordinary clock")
	if Engine.max_fps != 0 or OS.get_cmdline_args().has("--fixed-fps"): return fail("must run without --fixed-fps (registry needs.clock = ordinary)")
	if not FileAccess.file_exists(SAVE) or FileAccess.get_sha256(SAVE) != SAVE_SHA: return fail("owner L8 save missing or changed (local input " + SAVE + ")")
	var err: String = GameSave.load_file(self, ProjectSettings.globalize_path(SAVE))
	if not err.is_empty(): return fail("load: " + err)
	var session: Node = root.get_node("GameSession")
	var scene: Node = null
	for i in 3000:
		await process_frame
		scene = current_scene
		if scene != null and scene.scene_file_path.ends_with("darker_jungle.tscn") and is_instance_valid(scene.get("player")) and session.pending_resume.is_empty() and not session.changing_scene: break
	if scene == null or not scene.scene_file_path.ends_with("darker_jungle.tscn"): return fail("the save did not resume L8")
	for i in 120: await process_frame
	var at: Vector3 = scene.player.global_position
	if Vector2(at.x + 4287.3, at.z - 1182.8).length() > 8.0: return fail("not at his stand: %s" % str(at))
	root.add_child(Bracket.new(true, marks)); root.add_child(Bracket.new(false, marks))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var frames: Array = []
	var last := Time.get_ticks_usec(); var t0 := Time.get_ticks_msec(); var n := 0
	while Time.get_ticks_msec() - t0 < STAND_MS:
		await process_frame
		n += 1
		var now := Time.get_ticks_usec(); frames.append((now - last) / 1000.0); last = now
		if n % 30 == 0:
			var m := InputEventMouseMotion.new(); m.relative = Vector2(60, 0); Input.parse_input_event(m); Input.flush_buffered_events()
	var steps: Array = []; var open := -1
	for mk in marks:
		if mk[0]: open = mk[1]
		elif open >= 0: steps.append((mk[1] - open) / 1000.0); open = -1
	frames = frames.slice(10); steps = steps.slice(30)
	if frames.size() < 20 or steps.size() < 60: return fail("too few frames (%d) or steps (%d)" % [frames.size(), steps.size()])
	var f := stats(frames); var s := stats(steps)
	var moved: float = Vector2(scene.player.global_position.x - at.x, scene.player.global_position.z - at.z).length()
	print("L8 STAND frames %d steps %d moved %.1f: frame ms mean %.1f p50 %.1f p95 %.1f worst %.1f; script ms per physics step mean %.2f p50 %.2f p95 %.2f worst %.2f (budgets frame mean %.0f p95 %.0f, step mean %.1f worst %.1f)" % [frames.size(), steps.size(), moved, f.mean, f.p50, f.p95, f.worst, s.mean, s.p50, s.p95, s.worst, FRAME_MEAN_BUDGET_MS, FRAME_P95_BUDGET_MS, STEP_MEAN_BUDGET_MS, STEP_WORST_BUDGET_MS])
	if moved > 4.0: return fail("the player moved %.1f while standing" % moved)
	if FRAME_MEAN_BUDGET_MS > 0 and f.mean > FRAME_MEAN_BUDGET_MS: return fail("frame mean %.1f ms over %.0f" % [f.mean, FRAME_MEAN_BUDGET_MS])
	if FRAME_P95_BUDGET_MS > 0 and f.p95 > FRAME_P95_BUDGET_MS: return fail("frame p95 %.1f ms over %.0f" % [f.p95, FRAME_P95_BUDGET_MS])
	if STEP_MEAN_BUDGET_MS > 0 and s.mean > STEP_MEAN_BUDGET_MS: return fail("physics step script mean %.2f ms over %.1f" % [s.mean, STEP_MEAN_BUDGET_MS])
	if STEP_WORST_BUDGET_MS > 0 and s.worst > STEP_WORST_BUDGET_MS: return fail("physics step script worst %.2f ms over %.1f" % [s.worst, STEP_WORST_BUDGET_MS])
	print("PASS l8_stand_frame_budget_input: the owner's L8 stand stays inside the frame and physics-step budgets")
	quit(0)
