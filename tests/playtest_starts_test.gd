extends SceneTree
## Playtest starts (docs/playtest-starts.md). Headless:
##  1. the committed manifest parses; every entry's staged save exists, matches its sha256 pin and passes the game's own
##     reader/validator for its resume kind (scripts/lol2/playtest_starts.gd);
##  2. the original-game gate offers "Playtest starts (F2)"; F2 opens a plain list whose rows are the manifest titles in
##     manifest order; F2 closes it again;
##  3. refusals: an unknown id and an unverified executable stay on the gate with a message and set no resume meta;
##  4. every entry, chosen by its list row, resumes through the gate's existing area branch into the right scene with the
##     saved player position; the resume meta is consumed, the gate's own save paths are restored, and no user quicksave
##     is written or changed by starting.
## Needs the staged generated folder (tools/prepare_playtest_starts.py) and LOL2_ORIGINAL_GAME_EXE (verified LOLG.EXE).
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const GATE := "res://scenes/lol2/original_game_gate.tscn"
const META := {"museum": "lol2_museum_resume", "jungle": "lol2_jungle_resume", "hive": "lol2_hive_resume", "darker": "lol2_darker_resume", "dark_halls": "lol2_dark_halls_resume"}
const SCRIPTS := {"museum": "museum_walkthrough.gd", "jungle": "jungle_walkthrough.gd", "hive": "hive_review.gd", "darker": "darker_jungle.gd", "dark_halls": "dark_halls.gd"}
var failures := 0
var exe := OS.get_environment("LOL2_ORIGINAL_GAME_EXE")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		print("FAIL: " + message)
	return condition

func _initialize() -> void: run.call_deferred()

func user_saves() -> Dictionary:
	var found := {}
	var dir := DirAccess.open("user://saves")
	if dir == null: return found
	for name in dir.get_files(): found[name] = FileAccess.get_sha256("user://saves/" + name)
	return found

func new_gate() -> Node:
	var gate = load(GATE).instantiate()
	# A fresh, absent settings file per gate: empty path field, so no automatic cavern start (a start writes the file).
	var settings := "user://tests/playtest_starts_%d.cfg" % Time.get_ticks_usec()
	gate.settings_path = settings
	root.add_child(gate)
	current_scene = gate
	await process_frame
	await process_frame
	check(current_scene == gate, "gate stays up (no automatic start)")
	return gate

func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame

func run() -> void:
	if not check(not exe.is_empty() and FileAccess.file_exists(exe), "LOL2_ORIGINAL_GAME_EXE names the original LOLG.EXE"):
		quit(1); return
	# 1. Manifest and staged files.
	var listed := Starts.manifest()
	check(listed.error.is_empty(), "manifest parses: " + str(listed.error))
	var entries: Array = listed.entries
	check(entries.size() == 11, "11 Act 1 starts (%d)" % entries.size())
	var states := {}
	for entry in entries:
		check(Starts.file_error(entry).is_empty(), "%s staged and sha256-pinned: %s" % [entry.id, Starts.file_error(entry)])
		var read: Dictionary = Starts.read(entry)
		if check(str(read.error).is_empty(), "%s passes the game's save validator: %s" % [entry.id, read.error]):
			check(str(read.state.format) == str(Starts.KINDS[str(entry.resume)].format), "%s format matches its resume kind" % entry.id)
			states[entry.id] = read.state
			var identity := Starts.identity_error(entry, read.state)
			check(identity.is_empty(), "%s carries its pinned identities: %s" % [entry.id, identity])
	# Identity controls: a pinned item/flag that the save does not carry is reported (no false pass).
	if states.has("act1-hive-entry"):
		var probe: Dictionary = entries.filter(func(e: Dictionary) -> bool: return e.id == "act1-hive-entry")[0].duplicate(true)
		probe.identities.contains = {"inventory.collected": ["monastery:item94:Iron_Flute"]}
		check(not Starts.identity_error(probe, states["act1-hive-entry"]).is_empty(), "identity control: Hive entry save without the flute is caught")
		probe.identities.contains = {}
		probe.identities.values = {"quests.monastery.globals.GV_MET_BACATTA": 1}
		check(not Starts.identity_error(probe, states["act1-hive-entry"]).is_empty(), "identity control: wrong quest flag is caught")
	for entry in entries:
		check(str(entry.source.commit).length() == 40 and entry.source.has("input_sha256"), "%s pins test, commit and input sha256" % entry.id)
	var good := {"id": "x", "title": "x", "act": 2, "area": "x", "resume": "hive", "save": "x.json", "sha256": "0".repeat(64),
		"source": {"test": "t", "commit": "0".repeat(40), "input_sha256": null}, "identities": {"contains": {"a": ["b"]}, "excludes": {}, "values": {}}}
	check(Starts.entry_error(good) == "", "control entry is well formed: " + Starts.entry_error(good))
	var bad: Dictionary = good.duplicate(true); bad.resume = "map"
	check(Starts.entry_error(bad).begins_with("unknown resume kind"), "an unknown resume kind (Act 2 map save) is refused")
	bad = good.duplicate(true); bad.save = "../x.json"
	check(Starts.entry_error(bad) == "unsafe save name", "a path in the save name is refused")
	bad = good.duplicate(true); bad.source.erase("commit")
	check(Starts.entry_error(bad) == "source missing commit", "an entry without the producing commit is refused")
	bad = good.duplicate(true); bad.source.input_sha256 = "abc"
	check(Starts.entry_error(bad) == "bad source.input_sha256", "a malformed input sha256 is refused")
	bad = good.duplicate(true); bad.identities = {"contains": {}, "excludes": {}, "values": {}}
	check(Starts.entry_error(bad) == "identities pin nothing", "an entry pinning no identities is refused")
	var before_saves := user_saves()
	# 2. Gate button, F2 list in manifest order.
	var gate = await new_gate()
	var button: Button = gate.find_child("PlaytestStarts", true, false)
	check(button != null and button.text == "Playtest starts (F2)", "gate offers 'Playtest starts (F2)'")
	await key(KEY_F2)
	check(gate.starts_panel != null and gate.starts_panel.visible, "F2 opens the playtest start list")
	var rows: Array = []
	if gate.starts_panel != null:
		for node in gate.starts_panel.find_children("Start_*", "Button", true, false): rows.append(node)
	var titles: Array = rows.map(func(row: Button) -> String: return row.text)
	var expected: Array = entries.map(func(entry: Dictionary) -> String: return str(entry.title))
	check(titles == expected, "list rows are the manifest titles in order: %s" % [titles])
	check(rows.all(func(row: Button) -> bool: return not row.disabled), "every row is enabled (all saves staged)")
	await key(KEY_F2)
	check(gate.starts_panel != null and not gate.starts_panel.visible, "F2 closes the list")
	# 3. Refusals stay on the gate.
	gate.path_field.text = exe
	gate.start_playtest("no-such-start")
	check(current_scene == gate and gate.status.text.contains("Unknown playtest start"), "unknown id refused on the gate")
	gate.path_field.text = ""
	gate.start_playtest(str(entries[0].id))
	await process_frame
	check(current_scene == gate and not get_meta("original_game_verified") and not has_meta(META.museum), "unverified executable: no start, no resume meta")
	gate.queue_free()
	await process_frame
	# 4. Every entry through its list row.
	for entry in entries:
		gate = await new_gate()
		gate.path_field.text = exe
		var kept: Array = [gate.museum_save_path, gate.jungle_save_path, gate.hive_save_path, gate.darker_save_path, gate.dark_halls_save_path]
		gate.show_playtest_starts()
		var row: Button = gate.starts_panel.find_child("Start_" + str(entry.id), true, false)
		if not check(row != null, "%s row present" % entry.id): continue
		row.pressed.emit()
		check(is_instance_valid(gate) and [gate.museum_save_path, gate.jungle_save_path, gate.hive_save_path, gate.darker_save_path, gate.dark_halls_save_path] == kept, "%s: gate save paths restored after the start" % entry.id)
		var scene: Node = null
		for i in 600:
			await process_frame
			if current_scene != gate and current_scene != null:
				scene = current_scene
				break
		if not check(scene != null, "%s: left the gate (status: %s)" % [entry.id, gate.status.text if is_instance_valid(gate) else "freed"]):
			if is_instance_valid(gate): gate.queue_free()
			await process_frame
			continue
		var kind := str(entry.resume)
		check(scene.get_script().resource_path.ends_with(SCRIPTS[kind]) and scene.scene_file_path == str(Starts.KINDS[kind].scene), "%s resumes into %s (%s)" % [entry.id, Starts.KINDS[kind].scene, scene.scene_file_path])
		check(get_meta("original_game_verified") and not has_meta(META[kind]), "%s: verified start, resume meta consumed" % entry.id)
		for i in 5: await process_frame
		var saved: Array = states.get(entry.id, {}).get("player", {}).get("position", [0, 0, 0])
		var at: Vector3 = scene.player.position
		check(Vector2(at.x - float(saved[0]), at.z - float(saved[2])).length() < 2.0, "%s: player at the saved position %s (%s)" % [entry.id, saved, at])
		print("START ", entry.id, " -> ", scene.scene_file_path, " at ", at)
		scene.queue_free()
		current_scene = null
		for i in 3: await process_frame
	check(user_saves() == before_saves, "no user quicksave written or changed by the starts")
	print("playtest starts: %d failures" % failures)
	if failures == 0: print("PASS playtest starts: %d sha-pinned earned saves validate and resume through the gate's area branches into their scenes; F2 list in manifest order; refusals stay on the gate; user saves untouched" % entries.size())
	quit(0 if failures == 0 else 1)
