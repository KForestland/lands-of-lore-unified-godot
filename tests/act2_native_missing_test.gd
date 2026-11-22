extends SceneTree
## Lead 2026-11-15 (approved 17:3xZ): a level that starts without its native script export has no progression (doors,
## lifts, movies, level changes), so it must fail loudly instead of looking like a game fault. act2_map pushes an
## error (the regression runner fails any test whose log has ERROR:) and shows the line for 30 s on screen.
const Binder = preload("res://scripts/lol2/act2_progression.gd")
var failed := false
func check(ok: bool, what: String) -> void:
	if not ok: failed = true; print("FAIL act2_native_missing: ", what)
func _initialize():
	var staged: Array = []
	for file in DirAccess.get_files_at(Binder.NATIVE_ROOT):
		if file.ends_with(".json"): staged.append(file.get_basename())
	staged.sort()
	var listed: Array = Binder.NATIVE_AREAS.duplicate(); listed.sort()
	check(staged == listed, "the fifteen listed areas are exactly the staged export (staged %s)" % [staged])
	for area in Binder.NATIVE_AREAS: check(Binder.native_missing(area).is_empty(), "staged %s is not reported" % area)
	var missing := Binder.native_missing("L12_CM", "res://tests/no_such_native_root/")
	check(missing.begins_with("L12_CM native scripts are not staged") and missing.contains("level changes will not work"), "an unstaged L12 is named (got '%s')" % missing)
	check(Binder.native_missing("L2_MU", "res://tests/no_such_native_root/").is_empty(), "a level without a native export is not reported")
	var source := FileAccess.get_file_as_string("res://scripts/lol2/act2_map.gd")
	check(source.contains("elif not Binder.native_missing(area_id).is_empty():") and source.contains("push_error(\"act2_map: \" + missing)"), "act2_map reports the missing export")
	if not failed: print("PASS act2_native_missing: the fifteen exported levels are listed; an unstaged one is named with an error and a screen line")
	quit(1 if failed else 0)
