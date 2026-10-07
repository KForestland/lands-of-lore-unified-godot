extends SceneTree

const Save = preload("res://scripts/lol2/walkthrough_save.gd")
var cases := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
	cases += 1

func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= maxf(1.0, absf(float(a))) * 1e-12
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not equivalent(a[index], b[index]): return false
		return true
	return a == b

func _initialize() -> void:
	var path := "user://tests/save_%d/quicksave.json" % Time.get_ticks_usec()
	var state := {
		"format": Save.FORMAT, "version": Save.VERSION, "map": Save.MAP_ID,
		"checkpoint": 118,
		"collected": [],
		"player": {"position": [-430.59923453546287, 249.0, 1268.6443814488684],
			"yaw": -2.123456789, "camera_rotation": [-0.15, 0.0, 0.0], "flying": false},
		"display": {"lighting": true, "glow": true, "props": true, "roof": false, "creatures": true}}
	check(Save.write_save(path, state, 119).is_empty(), "Write initial save")
	var loaded := Save.read_save(path, 119)
	check(loaded.error.is_empty(), "Read initial save")
	check(equivalent(loaded.state, state), "JSON round trip within 1e-12 relative numeric tolerance")
	state.player.flying = true
	state.player.position[1] += 100
	check(Save.write_save(path, state, 119).is_empty(), "Replace existing save")
	check(equivalent(Save.read_save(path, 119).state, state), "Replacement round trip")
	var previous := FileAccess.get_file_as_bytes(path)
	for invalid in [null, [], {}, {"format": "original-dos-save"}]:
		check(not Save.validate(invalid, 119).is_empty(), "Reject invalid root")
	for entry in [["version", 3], ["version", "1"], ["map", "other"],
		["checkpoint", -1], ["checkpoint", 119], ["checkpoint", 0.5],
		["checkpoint", true], ["checkpoint", INF], ["checkpoint", NAN],
		["player", []], ["display", null]]:
		var invalid: Dictionary = state.duplicate(true)
		invalid[entry[0]] = entry[1]
		check(not Save.write_save(path, invalid, 119).is_empty(), "Reject invalid " + str(entry[0]))
		check(FileAccess.get_file_as_bytes(path) == previous, "Invalid state preserves previous save")
	for entry in [["position", [1, 2]], ["position", [1, 2, NAN]],
		["position", ["0", 1, 2]], ["position", [1e30, 0, 0]],
		["yaw", INF], ["yaw", 10], ["flying", 1], ["camera_rotation", [0, 0, INF]]]:
		var invalid: Dictionary = state.duplicate(true)
		invalid.player[entry[0]] = entry[1]
		check(not Save.validate(invalid, 119).is_empty(), "Reject invalid player " + str(entry[0]))
	for flag in Save.DISPLAY_FLAGS:
		var invalid: Dictionary = state.duplicate(true)
		invalid.display[flag] = "true"
		check(not Save.validate(invalid, 119).is_empty(), "Reject non-boolean display flag")
	for ids in [null, {}, ["unknown"], [Save.Collectible.ID, Save.Collectible.ID], [1108]]:
		var invalid: Dictionary = state.duplicate(true)
		invalid.collected = ids
		check(not Save.write_save(path, invalid, 119).is_empty(), "Reject invalid collected IDs")
		check(FileAccess.get_file_as_bytes(path) == previous, "Invalid collection preserves save")
	state.collected = [Save.Collectible.ID]
	check(Save.write_save(path, state, 119).is_empty(), "Save collected object")
	check(Save.read_save(path, 119).state.collected == state.collected, "Read collected object")
	var legacy: Dictionary = state.duplicate(true)
	legacy.version = 1
	legacy.erase("collected")
	var legacy_file := FileAccess.open(path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	previous = FileAccess.get_file_as_bytes(path)
	var migrated := Save.read_save(path, 119)
	check(migrated.error.is_empty(), "Read version 1 save")
	check(migrated.state.version == 2 and migrated.state.collected == [], "Migrate v1 to uncollected state")
	check(FileAccess.get_file_as_bytes(path) == previous, "Loading legacy save does not rewrite it")
	var blocked := path.get_base_dir() + "/blocked"
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	check(not Save.write_save(blocked + "/save.json", state, 119).is_empty(), "Report write failure")
	check(FileAccess.get_file_as_bytes(path) == previous, "Failed write preserves existing save")
	for bad_text in ["{", "{}", "null", "[]", " ".repeat(Save.MAX_BYTES + 1)]:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(bad_text)
		file.close()
		check(not Save.read_save(path, 119).error.is_empty(), "Reject damaged or oversized save")
	DirAccess.remove_absolute(path)
	check(not Save.read_save(path, 119).error.is_empty(), "Report missing save")
	DirAccess.remove_absolute(blocked)
	DirAccess.remove_absolute(path.get_base_dir())
	print("Save validation: %d checks, %d failures" % [cases, failures])
	quit(1 if failures else 0)
