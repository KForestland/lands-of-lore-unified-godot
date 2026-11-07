extends SceneTree
## W4 (2026-10-31): the test registry is consistent. Runs tools/check_registry.py (every tests/registry/<name>.json loads
## through run_regressions.py, every SceneTree test is registered or in _unregistered.txt, orders are non-negative; equal orders run in name order, W16) and reads the
## registry itself: this test's own file is there, in core, headless.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/check_registry.py")], out, true)
	check(code == 0, "tools/check_registry.py exits 0 (%d): %s" % [code, "".join(out).strip_edges()])
	var own := "res://tests/registry/test_registry_test.json"
	check(FileAccess.file_exists(own), "this test is registered")
	if FileAccess.file_exists(own):
		var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(own))
		check(str(entry.get("name")) == "test_registry_test" and str(entry.get("suite")) == "core" and str(entry.get("mode")) == "headless", "registered as core/headless (%s)" % [entry])
	var count := 0
	var dir := DirAccess.open("res://tests/registry")
	if dir != null:
		for f in dir.get_files(): if f.ends_with(".json"): count += 1
	check(count >= 596, "the registry holds the 596 former suite tests and the W4 additions (%d)" % count)
	print("test registry: %d failures" % failures)
	if failures == 0: print("PASS test registry: %s" % "".join(out).strip_edges())
	quit(0 if failures == 0 else 1)
