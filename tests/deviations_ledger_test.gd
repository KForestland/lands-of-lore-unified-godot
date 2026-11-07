extends SceneTree
## W4 (2026-10-31): docs/DEVIATIONS.md is rendered from the one-row-per-file pieces under docs/deviations/ by
## tools/build_deviations.py; `--check` exits 1 when the rendered ledger differs from the committed file (a hand edit of
## DEVIATIONS.md, or a piece edited without rebuilding). The row pieces are counted against the ledger's data rows.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var out := []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/build_deviations.py"), "--check"], out, true)
	check(code == 0, "tools/build_deviations.py --check exits 0 (%d): %s" % [code, "".join(out).strip_edges()])
	var rows := 0
	var row_re := RegEx.create_from_string("^\\| \\d{4}-\\d{2}-\\d{2} \\|")
	for line in FileAccess.get_file_as_string("res://docs/DEVIATIONS.md").split("\n"):
		if row_re.search(line) != null: rows += 1
	var pieces := 0
	var dir := DirAccess.open("res://docs/deviations")
	if dir != null:
		for f in dir.get_files(): if f.contains("-row-") and f.ends_with(".md"): pieces += 1
	check(rows > 0 and rows == pieces, "one row piece per ledger data row (%d rows, %d row pieces)" % [rows, pieces])
	print("deviations ledger: %d failures" % failures)
	if failures == 0: print("PASS deviations ledger: rendered from %d row pieces, byte-identical to docs/DEVIATIONS.md" % pieces)
	quit(0 if failures == 0 else 1)
