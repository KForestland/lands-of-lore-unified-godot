extends SceneTree
## Script-time budget, first level: Darker Jungle (L8). Owner r19p 2026-11-17 (F10 14-47-31 at -4287, 1183: 'the
## framerate goes down and the game feels sluggish'; 'shaking and slow frame rate'). Cause: the item catalog's name search
## ran from per-frame code for every carried item (belt slot resolve each frame, player_defense.scalar from every creature
## tick): 35 items -> 2.2 ms process + 7 ms physics a frame over r19o12 (Xvfb). Fix: Catalog.definition remembered per id.
## What it measures: only the game's own script work per frame (process and physics, bracketed by nodes at the lowest and
## highest priorities). Rendering is NOT measured, so this is not the frame time the owner sees.
## How: resumes the owner's own L8 F10 save (local only: tmp/l8_perf_inputs, OWNER_DERIVED.md) and WALKS from that pose for
## 20 s with real W/S and mouse look; it does not stand at his spot. As a rendered gate test it runs on the runner's private
## Xvfb at 1280x720, gl_compatibility, with --fixed-fps 60 (run_regressions.py), not on the ordinary clock.
## Fails when the mean or the worst frame's script time goes over its budget.
const GameSave = preload("res://scripts/lol2/game_save.gd")
const SAVE := "res://tmp/l8_perf_inputs/owner_144731.json"
const SAVE_SHA := "8d7f48ea36d5b44d0b56ddc539b9ed16f69c034f41057a2bd496f91655075e0b"
## Budgets for the Xvfb gate on this machine (2026-11-17, two runs each): fixed mean 16.0 / worst 20.5-21.2 ms; r19p
## 3e2e65c5 unfixed mean 25.4 / worst 32.3-32.9 ms; r19o12 matches the fixed build (process 29.9 vs 28.6, physics 16.0 vs
## 15.1 ms in the rendered walk probe). A slower gate host needs its own numbers.
const MEAN_BUDGET_MS := 20.0
const WORST_BUDGET_MS := 27.0
const WALK_MS := 20000

class Bracket extends Node:
	var first := true
	var t := 0
	var log: Array
	func _init(is_first: bool, into: Array) -> void:
		first = is_first; log = into
		process_priority = -1000000 if first else 1000000
		process_physics_priority = -1000000 if first else 1000000
	func _process(_d: float) -> void: _mark(0)
	func _physics_process(_d: float) -> void: _mark(1)
	func _mark(kind: int) -> void:
		log.append([kind, first, Time.get_ticks_usec()])

var marks: Array = []

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> void:
	push_error("FAIL l8_script_time_budget_input: " + message); quit(1)

func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()

func run() -> void:
	if DisplayServer.get_name() == "headless" or Engine.time_scale != 1.0: return fail("rendered ordinary clock")
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
	var start: Vector3 = scene.player.global_position
	var carried: int = scene.item_effects.carried().size() if scene.get("item_effects") != null else -1
	root.add_child(Bracket.new(true, marks)); root.add_child(Bracket.new(false, marks))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	key(KEY_W, true)
	var frames := 0
	var path := 0.0
	var last: Vector3 = start
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < WALK_MS:
		await process_frame
		frames += 1
		path += scene.player.global_position.distance_to(last); last = scene.player.global_position
		if frames % 90 == 0:
			var m := InputEventMouseMotion.new(); m.relative = Vector2(400, 0); Input.parse_input_event(m); Input.flush_buffered_events()
		if frames % 600 == 0: key(KEY_W, false); key(KEY_S, true)
		if frames % 600 == 300: key(KEY_S, false); key(KEY_W, true)
	key(KEY_W, false); key(KEY_S, false)
	# Script time per rendered frame: each process span plus the physics spans since the previous process span.
	var per_frame: Array = []
	var opened := {0: -1, 1: -1}
	var physics_us := 0
	for m in marks:
		var kind: int = m[0]
		if m[1]: opened[kind] = m[2]
		elif opened[kind] >= 0:
			var span: int = m[2] - opened[kind]; opened[kind] = -1
			if kind == 1: physics_us += span
			else: per_frame.append((span + physics_us) / 1000.0); physics_us = 0
	per_frame = per_frame.slice(5)
	if per_frame.size() < 100: return fail("too few frames measured (%d)" % per_frame.size())
	var sorted := per_frame.duplicate(); sorted.sort()
	var total := 0.0
	for x in sorted: total += x
	var mean: float = total / sorted.size()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	var worst: float = sorted[-1]
	var moved: float = path
	print("L8 SCRIPT BUDGET carried %d, frames %d, walked %.0f: script ms/frame mean %.2f p50 %.2f p99 %.2f worst %.2f (budget mean %.1f worst %.1f)" % [carried, sorted.size(), moved, mean, sorted[sorted.size() / 2], p99, worst, MEAN_BUDGET_MS, WORST_BUDGET_MS])
	if moved < 300: return fail("real W did not walk (path %.0f)" % moved)
	if MEAN_BUDGET_MS > 0 and mean > MEAN_BUDGET_MS: return fail("L8 script time mean %.2f ms a frame is over the %.1f ms budget" % [mean, MEAN_BUDGET_MS])
	if WORST_BUDGET_MS > 0 and worst > WORST_BUDGET_MS: return fail("L8 worst frame script time %.2f ms is over the %.1f ms budget" % [worst, WORST_BUDGET_MS])
	print("PASS l8_script_time_budget_input: the owner's L8 walk stays inside the script-time budget")
	quit()
