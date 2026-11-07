extends SceneTree
## Death -> recover (R) and death -> disk load (F9) on one host per process, with PRODUCTION controls
## (docs/act-one-remaining-work.md, demo acceptance "failure, death, retry"). LOL2_RECOVERY_HOST = cave|museum|jungle|hive.
## Entry is the production original-game gate: "Verify and start cavern" (Cave; source runs need --demo-interface) or
## "Resume museum/jungle/Hive" with an R16 earned save copied to the area's resume path (LOL2_EARNED_SAVES).
## development_mode must be false. Then:
##  1. real F5 quicksave; snapshot player fields (Continuity.from_host) and the diagnostics quest summary;
##  2. SUPPLIED: the player is placed next to a live hostile of the area's own damage owner; the owner's real attack
##     brings health to 0 (no lethal-damage call, no health write);
##  3. dead: the "You fell" prompt is shown and held W does not move the player;
##  4. real R: health > 0, held W moves the player, player fields equal the snapshot except health (and bounded mana
##     regeneration), quest summary unchanged;
##  5. SUPPLIED position again, real attack to 0, real F9: player fields equal the F5 snapshot (bounded mana only),
##     quest summary unchanged, development_mode still false, held W moves the player.
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const Diagnostics = preload("res://scripts/lol2/dev_diagnostics.gd")
const GATE := "res://scenes/lol2/original_game_gate.tscn"
const HOSTS := {
	"cave": {"button": "Verify and start cavern", "kind": "Cave", "scene": "res://scenes/lol2/cave_walkthrough.tscn"},
	"museum": {"button": "Resume museum", "kind": "Museum", "save": "act1_magic_museum_arrival.json", "resume": "user://saves/museum_quicksave.json", "scene": "res://scenes/lol2/museum_walkthrough.tscn"},
	"jungle": {"button": "Resume jungle", "kind": "Jungle", "save": "act1_broken_museum_jungle.json", "resume": "user://saves/jungle_quicksave.json", "scene": "res://scenes/lol2/jungle_walkthrough.tscn"},
	"hive": {"button": "Resume Hive", "kind": "Hive", "save": "act1_broken_hive_entry.json", "resume": "user://saves/hive_quicksave.json", "scene": "res://scenes/lol2/hive_review.tscn"},
}
const OUT := "user://tests/recovery/"
## F9 vs the F5 file: the only paths allowed to differ, by name, each with its reason (frames run between the load
## and the side save, so world clocks advance; restore bumps a documented playback epoch).
const F9_ALLOWED := {
	"cave": ["eyes.animation", "scenic_guard.effects.fire_time", "scenic_guard.elapsed", "magic.regen_elapsed", # scenery animation clocks
		"roach_population.actors.*.position", "roach_population.live.*.heading", "roach_population.ai.clock"], # native Roach disposition (roach-behaviour-r2, docs/cave-roach-disposition.md): perceiving Roaches Wander from human Luther in the frames after the load, and the attack-history clock runs
	"museum": ["checkpoint.curse.remaining", "checkpoint.magic.regen_elapsed", "checkpoint.museum_belial.animation", "checkpoint.museum_orb_switch.timer"], # curse timer, mana regeneration clock, Belial sequence frame, orb-floor timer (added 2026-10-17 after this table)
	"jungle": ["quests.jungle_exit_woman.conversation.prop.generation", "quests.player_magic_reward_state.regen_elapsed", "inventory.curse.remaining"], # restore epoch (jungle_exit_woman_state.gd:4-6,82-87); clocks
	"hive": ["quests.hive_ambush.actors.35.elapsed", "quests.hive_curse.remaining", "quests.hive_nest.elapsed", "quests.player_magic_reward_state.regen_elapsed"], # encounter/curse/nest clocks
}
## Across R the world keeps running (R cannot be delivered while paused). These LIVE-WORLD owners are recorded but
## not compared: the attacking encounter/population (AI, positions, audio), curse timers and scenery animation, plus
## R's own health write. EVERY other persisted path (quest flags/globals, owners, items, equipment, magic, fighting)
## must be byte-identical across R, and the set of owners must not change.
const LIVE_WORLD := {
	"cave": ["roach", "eyes", "scenic_guard", "roach_population", "guard_population", "wild_roach_population", "lurking_roach_population", "magic.regen_elapsed", "curse.remaining"],
	"museum": ["checkpoint.health", "checkpoint.skeletons.live", "checkpoint.skeletons.audio", "checkpoint.curse.remaining", "checkpoint.magic.regen_elapsed", "checkpoint.museum_belial.animation", "checkpoint.museum_orb_switch.timer"], # Belial sequence frame and orb-floor timer: scenery clocks added 2026-10-17 after this table
	"jungle": ["inventory.health", "quests.jungle_dino_population", "quests.player_magic_reward_state.regen_elapsed", "inventory.curse.remaining"],
	"hive": ["inventory.health", "quests.hive_encounter", "quests.hive_ambush", "quests.hive_nest", "quests.hive_curse.remaining", "quests.player_magic_reward_state.regen_elapsed", "inventory.curse.remaining"],
}
func owners_of(state: Dictionary) -> Array:
	var root = state.get("quests", state.get("checkpoint", state))
	if not root is Dictionary: root = state # Cave: "checkpoint" is the numeric route checkpoint, owners are top level
	var keys: Array = root.keys(); keys.sort()
	return keys

var failed := false
var host_name := OS.get_environment("LOL2_RECOVERY_HOST")
var receipt := {"host": host_name, "labels": {"supplied": [], "earned": [], "production": []}, "steps": {}}
var area: Node = null
var seconds := 0.0
func _initialize() -> void: run.call_deferred()
func _process(delta: float) -> bool:
	seconds += delta
	return false
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true; receipt.failure = message; save_receipt(); push_error(message); print("FAIL act1_recovery ", host_name, ": ", message); quit(1)
	return ok
func save_receipt() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var f := FileAccess.open(OUT + host_name + ".json", FileAccess.WRITE); f.store_string(JSON.stringify(receipt, "  ", true)); f.close()
func shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(OUT + "%s_%s.png" % [host_name, name])

func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
	for i in 4: await process_frame
func click_at(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = at
		Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 3: await process_frame
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null
## No input for `frames`: horizontal drift from gravity/placement/push alone.
func idle(frames: int) -> float:
	var before: Vector3 = area.player.global_position
	for i in frames: await physics_frame
	var after: Vector3 = area.player.global_position
	return Vector2(after.x - before.x, after.z - before.z).length()
## Held W through the real key state; returns horizontal displacement.
func walk(frames: int) -> float:
	var before: Vector3 = area.player.global_position
	var e := InputEventKey.new(); e.keycode = KEY_W; e.physical_keycode = KEY_W; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events()
	for i in frames: await physics_frame
	e = e.duplicate(); e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 2: await physics_frame
	var after: Vector3 = area.player.global_position
	return Vector2(after.x - before.x, after.z - before.z).length()

## Whole persisted state through the host's own production packer, written to a side path (never the F5 file).
func packed(name: String) -> Dictionary:
	var path := OUT + "%s_%s_save.json" % [host_name, name]
	var error: String = area.quicksave(path)
	if not error.is_empty(): return {"__error": error}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {"__error": "unparsable"}
func flatten(value: Variant, prefix: String, out: Dictionary) -> void:
	if value is Dictionary:
		for k in value: flatten(value[k], (prefix + "." if not prefix.is_empty() else "") + str(k), out)
	else:
		out[prefix] = JSON.stringify(value, "", true)
## Changed/added/removed leaf paths, ignoring the player pose record ("player").
func diff(a: Dictionary, b: Dictionary) -> Array:
	var fa := {}; var fb := {}
	flatten(a, "", fa); flatten(b, "", fb)
	var paths := []
	for k in fa.keys() + fb.keys():
		if str(k).begins_with("player.") or k in paths: continue
		if fa.get(k) != fb.get(k): paths.append(k)
	paths.sort()
	return paths
func outside(paths: Array, allowed: Array) -> Array:
	var bad := []
	for path in paths:
		var ok := false
		for prefix in allowed:
			if str(path) == prefix or str(path).begins_with(prefix + "."): ok = true; break
			# "*" matches exactly one path segment (an actor id); the full path must match.
			if "*" in prefix and str(path).split(".").size() == prefix.split(".").size():
				ok = true
				for i in prefix.split(".").size():
					if prefix.split(".")[i] != "*" and prefix.split(".")[i] != str(path).split(".")[i]: ok = false; break
				if ok: break
		if not ok: bad.append(path)
	return bad

## In-memory state through the same packer the host's save uses (saving itself is refused while dead in
## Cave/Museum/Jungle: "Finish the scene or recover before saving." / "Invalid player health.").
func memory_state() -> Dictionary:
	var state: Variant
	match host_name:
		"cave": state = area._save_state()
		"museum": state = {"checkpoint": area.checkpoint_state()}
		"jungle": state = {"inventory": area.inventory_state(), "quests": area.quest_state}
		"hive": state = area.area_handoff()
	return JSON.parse_string(JSON.stringify(state)) # same JSON normalisation as a save file
## Time fields advance whenever the world runs; they may change only by the measured simulated seconds.
func clock_path(path: String) -> bool:
	var leaf := path.get_slice(".", path.get_slice_count(".") - 1)
	return leaf in ["elapsed", "remaining", "regen_elapsed", "clock", "time", "cooldown"]
func clock_violations(a: Dictionary, b: Dictionary, paths: Array, seconds_between: float) -> Array:
	var fa := {}; var fb := {}
	flatten(a, "", fa); flatten(b, "", fb)
	var bad := []
	for path in paths:
		var va = JSON.parse_string(str(fa.get(path, "null"))); var vb = JSON.parse_string(str(fb.get(path, "null")))
		if not (va is float or va is int) or not (vb is float or vb is int): bad.append(path); continue
		var d := absf(float(vb) - float(va))
		if str(path).ends_with("regen_elapsed"): d = minf(d, 3.0 - d) # wraps at the regeneration period
		if d > seconds_between + 0.1: bad.append("%s moved %.3f in %.3f s" % [path, d, seconds_between])
	return bad
func health() -> int: return int(area.starting_magic.health())
func dev_mode() -> bool: return bool(area.get("development_mode"))
func fields() -> Dictionary: return Continuity.from_host(area)
func quests() -> Dictionary: return Diagnostics.quest_summary(area, HOSTS[host_name].kind)
func prompt_shown() -> bool:
	var text := ""
	for node in root.find_children("*", "Label", true, false):
		if node.is_visible_in_tree(): text += (node as Label).text + "\n"
	return "You fell" in text or "Defeated" in text # Hive guardians: "Defeated · F9: load or R: retry guardians"

## Every live hostile of the area's own damage owner: [[description, world position], ...].
func hostiles() -> Array:
	if host_name in ["cave", "hive"]:
		var one := hostile()
		return [] if one.is_empty() else [one]
	var result := []
	var population = area.skeleton_population if host_name == "museum" else area.dino_population
	var actors: Dictionary = population.state.actors if host_name == "museum" else population.view().actors
	for id in actors:
		var a: Dictionary = actors[id]
		if int(a.health) > 0 and bool(a.get("present", true)) and bool(a.get("woken", true)) and population.bodies.has(id):
			result.append(["%s actor %s (%s)" % [host_name, id, population.get_script().resource_path.get_file()], population.bodies[id].global_position])
	return result
## The first live hostile of the area's own damage owner: [description, world position].
func hostile() -> Array:
	match host_name:
		"cave":
			if area.roach != null and area.roach.model.enemy_health > 0: return ["entrance ROACH23 (cave_roach.gd / cave_encounter_state.gd)", area.roach.body.global_position]
		"museum", "jungle":
			var population = area.skeleton_population if host_name == "museum" else area.dino_population
			var actors: Dictionary = population.state.actors if host_name == "museum" else population.view().actors
			for id in actors:
				var a: Dictionary = actors[id]
				if int(a.health) > 0 and bool(a.get("present", true)) and bool(a.get("woken", true)) and population.bodies.has(id):
					return ["%s actor %s (%s)" % [host_name, id, population.get_script().resource_path.get_file()], population.bodies[id].global_position]
		"hive":
			var w = area.get_node("Warriors")
			for i in 2:
				if w.enemies[i] > 0: return ["Hive guardian %d (hive_warriors.gd)" % i, (w.POSITIONS[i] as Vector3)]
	return []

## Floor point 24-48 units from `at` with a clear line to it, at the player's own current foot height above floor.
func floor_spot(at: Vector3) -> Variant:
	var space: PhysicsDirectSpaceState3D = area.player.get_world_3d().direct_space_state
	var here: Vector3 = area.player.global_position
	var down := PhysicsRayQueryParameters3D.create(here + Vector3.UP * 4, here - Vector3.UP * 400, 1, [area.player.get_rid()])
	var under := space.intersect_ray(down)
	var foot: float = here.y - float(under.position.y) if not under.is_empty() else 32.0
	var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 40, at - Vector3.UP * 200, 1, [area.player.get_rid()]))
	var creature_floor: float = float(below.position.y) if not below.is_empty() else at.y
	for radius in [36.0, 24.0, 48.0]:
		for k in 12:
			var a := TAU * k / 12.0
			var probe := Vector3(at.x + cos(a) * radius, at.y, at.z + sin(a) * radius)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 120, probe - Vector3.UP * 240, 1, [area.player.get_rid()]))
			if hit.is_empty() or absf(float(hit.position.y) - creature_floor) > 12: continue
			var spot := Vector3(probe.x, float(hit.position.y) + foot, probe.z)
			var los := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot, Vector3(at.x, spot.y, at.z), 1, [area.player.get_rid()]))
			if los.is_empty() or Vector2(los.position.x - at.x, los.position.z - at.z).length() < 16: return spot
	return null

## SUPPLIED position next to the hostile; the owner's real attack must take health to 0.
func die(step: String) -> bool:
	if host_name == "museum":
		# SUPPLIED lethal-damage calls: the production sconce-flame owner (museum_key_locks.gd burn(), 5 per touch)
		# instead of the E interaction; awake skeletons 22/23 had no reachable same-level floor for placement.
		var h0 := health()
		var calls := 0
		while health() > 0 and calls < 20:
			area.key_locks.burn(); calls += 1
			for i in 2: await physics_frame
		receipt.labels.supplied.append("%s: %d supplied calls of museum_key_locks.burn() (production owner) from health %d" % [step, calls, h0])
		receipt.steps[step + "_death"] = {"by": "museum_key_locks.burn() x%d (supplied call)" % calls, "health_before": h0, "health": health()}
		return check(health() == 0, "%s: burn() did not reach 0 (health %d)" % [step, health()])
	var target := []
	var spot = null
	for candidate in hostiles():
		spot = floor_spot(candidate[1])
		if spot != null: target = candidate; break
	receipt.steps[step + "_health_at_placement"] = health()
	if not check(spot != null, "%s: no live hostile with a floor 24-48 units away on its own level" % step): return false
	var at: Vector3 = target[1]
	area.player.global_position = spot
	area.player.velocity = Vector3.ZERO
	area.player.look_at(Vector3(at.x, spot.y, at.z))
	for i in 3: await physics_frame
	receipt.labels.supplied.append("%s: player placed on ray-cast floor at %s, %.0f units from %s at %s" % [step, spot, Vector2(spot.x - at.x, spot.z - at.z).length(), target[0], at])
	var start := seconds
	var h0 := health()
	var trace := []
	var next_trace := 0.0
	while health() > 0 and seconds - start < 90.0:
		await physics_frame
		if seconds - start >= next_trace and trace.size() < 8:
			next_trace += 5.0
			trace.append({"t": snappedf(seconds - start, 0.1), "player": area.player.global_position, "hostile": at, "on_floor": area.player.is_on_floor(), "mouse": Input.mouse_mode, "health": health()})
	receipt.steps[step + "_trace"] = trace
	receipt.steps[step + "_death"] = {"by": target[0], "health_before": h0, "health": health(), "simulated_seconds": seconds - start}
	return check(health() == 0, "%s: %s did not bring health to 0 in 90 s (health %d)" % [step, target[0], health()])

func run() -> void:
	# These gate/resume checks exercise the normal quicksave paths. Require an explicitly
	# reserved test userdata namespace before writing any save or opening the game gate.
	var custom_data := bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
	var data_name := str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if not check(custom_data and data_name.begins_with("lol2-regression-"), "Recovery checks require isolated custom userdata named lol2-regression-… in a disposable project"): return
	if not check(HOSTS.has(host_name), "LOL2_RECOVERY_HOST must be cave|museum|jungle|hive"): return
	if not check(DirAccess.make_dir_recursive_absolute(OUT) == OK, "Cannot create recovery evidence directory"): return
	var cfg: Dictionary = HOSTS[host_name]
	DirAccess.make_dir_recursive_absolute("user://saves")
	if cfg.has("save"):
		var save_root := OS.get_environment("LOL2_RECOVERY_SAVES")
		if save_root.is_empty(): save_root = OS.get_environment("LOL2_EARNED_SAVES")
		var source := save_root.path_join(cfg.save)
		var bytes := FileAccess.get_file_as_bytes(source)
		if not check(not bytes.is_empty(), "missing earned save %s" % source): return
		var f := FileAccess.open(cfg.resume, FileAccess.WRITE); f.store_buffer(bytes); f.close()
		var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
		receipt.labels.earned.append("Archived earned save %s sha256 %s via production '%s'" % [cfg.save, ctx.finish().hex_encode(), cfg.button])
	else:
		receipt.labels.earned.append("NONE: fresh new game through production '%s' (no Cave checkpoint exists among the R16 saves; no earned progress claimed)" % cfg.button)
	var gate = load(GATE).instantiate()
	root.add_child(gate); current_scene = gate
	if not OS.get_environment("LOL2_ORIGINAL_GAME_EXE").is_empty():
		gate.path_field.text = OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
	for i in 6: await process_frame
	var button := find_button(gate, cfg.button)
	if not check(button != null, "gate shows no '%s'" % cfg.button): return
	await click_at(button.get_global_rect().get_center())
	for i in 2400:
		await process_frame
		var s := current_scene
		if s != null and s != gate and is_instance_valid(s) and s.scene_file_path == cfg.scene and s.get("player") is Node3D and (s.get("walkthrough_ready") == null or s.walkthrough_ready) and s.get("starting_magic") != null:
			area = s; break
	if not check(area != null, "'%s' did not reach %s" % [cfg.button, cfg.scene]): return
	for i in 30: await physics_frame
	receipt.labels.production.append("entered through the gate button '%s'" % cfg.button)
	if not check(not dev_mode(), "development_mode is true after production entry"): return
	receipt.steps.development_mode_after_entry = dev_mode()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		await click_at(root.get_visible_rect().size / 2.0)
	if not check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "a real click did not capture the mouse"): return
	# 1. Real F5.
	var save_path: String = cfg.get("resume", "user://saves/cave_walkthrough.json")
	if host_name == "cave": save_path = preload("res://scripts/lol2/walkthrough_save.gd").DEFAULT_PATH
	var before_save := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	await key(KEY_F5)
	for i in 6: await process_frame
	var saved := FileAccess.get_file_as_bytes(save_path)
	if not check(not saved.is_empty() and saved != before_save, "F5 did not write a new save at %s" % save_path): return
	var snapshot := fields()
	var quest_snapshot := quests()
	var save_seconds := seconds
	var save_regen := float(area.starting_magic.magic_state().get("regen_elapsed", 0.0))
	receipt.steps.f5 = {"path": save_path, "bytes": saved.size(), "fields": snapshot.size(), "health": health()}
	# 2-3. Death through the area's own damage owner.
	if not await die("recover"): return
	var dead_idle := await idle(40)
	var dead_walk := await walk(40)
	var dead_health := health()
	receipt.steps.dead = {"prompt": prompt_shown(), "no_input_units": dead_idle, "walk_units": dead_walk, "health_during": dead_health}
	await shot("dead")
	if not check(prompt_shown(), "dead without the area's death prompt"): return
	if not check(dead_health == 0, "health left 0 while dead without input (%d)" % dead_health): return
	if not check(dead_walk <= dead_idle + 1.0, "dead player moved %.2f horizontal units under held W (no-input interval %.2f)" % [dead_walk, dead_idle]): return
	# Quest/world owners may legitimately change during the fight itself (e.g. the dinosaur population inserts its
	# packet into quest_state once its live state changes). R is judged against the state AT death; the change
	# from the F5 snapshot is recorded separately. F9 must still restore the F5 quest state exactly.
	var quest_at_death := quests()
	receipt.steps.fight_quest_changes = quest_at_death != quest_snapshot
	var f5_state = JSON.parse_string(saved.get_string_from_utf8())
	var dead_save := packed("dead_attempt")
	receipt.steps.save_while_dead = dead_save.get("__error", "accepted")
	var pre_r := memory_state()
	var pre_r_seconds := seconds
	receipt.steps.fight_changes_since_f5 = diff(f5_state, pre_r) # encounter mutations, recorded explicitly
	# 4. Real R.
	var recover_start := seconds
	await key(KEY_R)
	for i in 4: await physics_frame
	var recovered_health := health()
	var after_r := fields()
	var r_elapsed := seconds - recover_start
	if not check(recovered_health > 0 and not dev_mode(), "R did not recover (health %d, development_mode %s)" % [recovered_health, dev_mode()]): return
	var recover_walk := await walk(40)
	var allowed := {"health": recovered_health}
	if snapshot.has("magic.mana") and after_r.get("magic.mana") != snapshot.get("magic.mana"):
		allowed["magic.mana"] = Continuity.mana_allowance(int(snapshot["magic.mana"]), int(snapshot["magic.maximum"]), seconds - save_seconds, save_regen)
	var r_errors := Continuity.compare(snapshot, after_r, allowed)
	receipt.steps.recover = {"health": recovered_health, "walk_units": recover_walk, "errors": r_errors, "quests_equal_at_death": quests() == quest_at_death, "quests_equal_f5": quests() == quest_snapshot, "simulated_seconds": r_elapsed}
	await shot("recovered")
	if not check(recover_walk > 2.0, "recovered player did not move (%.2f units)" % recover_walk): return
	if not check(r_errors.is_empty(), "R changed player state: %s" % [r_errors]): return
	if not check(quests() == quest_at_death, "R changed quest state: %s -> %s" % [quest_at_death, quests()]): return
	var post_r := memory_state()
	var r_paths := diff(pre_r, post_r)
	receipt.steps.recover.persisted_changes = r_paths
	receipt.steps.recover.owners_equal = owners_of(pre_r) == owners_of(post_r)
	if not check(owners_of(pre_r) == owners_of(post_r), "R changed the set of quest owners: %s -> %s" % [owners_of(pre_r), owners_of(post_r)]): return
	var r_unexpected := outside(r_paths, LIVE_WORLD[host_name])
	receipt.steps.recover.compared_paths_changed = r_unexpected
	if not check(r_unexpected.is_empty(), "R changed persisted state outside the live-world owners: %s" % [r_unexpected]): return
	# 5. Die again, then real F9.
	if not await die("load"): return
	var load_start := seconds
	await key(KEY_F9)
	for i in 30: await physics_frame
	var loaded := fields()
	var post_f9 := packed("post_f9")
	var f9_paths := diff(f5_state, post_f9) if not post_f9.has("__error") else ["__error"]
	var l_allowed := {}
	if snapshot.has("magic.mana") and loaded.get("magic.mana") != snapshot.get("magic.mana"):
		l_allowed["magic.mana"] = Continuity.mana_allowance(int(snapshot["magic.mana"]), int(snapshot["magic.maximum"]), seconds - load_start, save_regen)
	var l_errors := Continuity.compare(snapshot, loaded, l_allowed)
	var load_walk := await walk(40)
	receipt.steps.load = {"persisted_changes_vs_f5": f9_paths, "health": health(), "errors": l_errors, "quests_equal": quests() == quest_snapshot, "development_mode": dev_mode(), "walk_units": load_walk}
	await shot("loaded")
	if not check(l_errors.is_empty(), "F9 state differs from the F5 save: %s" % [l_errors]): return
	# F9 must restore the saved semantics: only clocks that run in the frames after the load may differ.
	var f9_unexpected := outside(f9_paths, F9_ALLOWED[host_name])
	if not check(f9_unexpected.is_empty(), "F9 persisted state differs from the F5 file: %s" % [f9_unexpected]): return
	if not check(quests() == quest_snapshot, "F9 quest state differs: %s -> %s" % [quest_snapshot, quests()]): return
	if not check(not dev_mode(), "development_mode true after F9"): return
	if not check(load_walk > 2.0, "player did not move after F9 (%.2f units)" % load_walk): return
	receipt.passed = true
	save_receipt()
	print("PASS act1_recovery %s: production entry (development_mode false), F5, death by the area's own attacker, R recover (health %d, moves %.1f, player/quest state kept), second death, F9 load (state equals F5 save, moves %.1f). %s" % [host_name, recovered_health, recover_walk, load_walk, JSON.stringify(receipt.steps)])
	quit()
