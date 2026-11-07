extends SceneTree
## Validator for tools/prepare_playtest_starts.py: reads every manifest entry's file in --dir=ABSOLUTE_DIR with the game's
## own save reader/validator for its resume kind (scripts/lol2/playtest_starts.gd -> museum/jungle/hive save owners), checks the
## entry's pinned identities (key items/quest flags) and
## prints one line "PLAYTEST_STARTS_VALIDATION <json>". --only=id1,id2 limits the entries; --manifest=PATH checks another manifest file (refusal controls). Exit 0 only when all pass.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")

func _initialize() -> void:
	var dir := ""
	var only: PackedStringArray = []
	var manifest := Starts.MANIFEST
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dir="): dir = argument.trim_prefix("--dir=")
		elif argument.begins_with("--only="): only = argument.trim_prefix("--only=").split(",", false)
		elif argument.begins_with("--manifest="): manifest = argument.trim_prefix("--manifest=")
	var listed := Starts.manifest(manifest)
	var results := []
	var ok: bool = str(listed.error).is_empty() and not dir.is_empty()
	for entry in listed.entries:
		if not only.is_empty() and str(entry.id) not in only: continue
		var path := dir.path_join(str(entry.save))
		var row: Dictionary = {"id": entry.id, "save": entry.save, "resume": entry.resume, "sha256": FileAccess.get_sha256(path)}
		var read: Dictionary = Starts.read(entry, path)
		row.error = str(read.error)
		if row.error.is_empty() and str(read.state.get("format")) != str(Starts.KINDS[str(entry.resume)].format):
			row.error = "format differs from the resume kind"
		if row.error.is_empty() and row.sha256 != str(entry.sha256): row.error = "sha256 differs from the manifest"
		if row.error.is_empty(): row.error = Starts.identity_error(entry, read.state)
		if not row.error.is_empty(): ok = false
		results.append(row)
	print("PLAYTEST_STARTS_VALIDATION ", JSON.stringify({"passed": ok, "manifest_error": listed.error, "entries": results}))
	quit(0 if ok else 1)
