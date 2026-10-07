extends SceneTree
func _initialize():
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-rune-response-checks.json"))
	for row in source.cases:
		var result := preload("res://scripts/lol2/hive_rune_speech.gd").response_plan(int(row.mask),row.draws)
		if result.has("error") or result.mask != row.result or result.line != (0 if row.calls.is_empty() else row.calls[0][1]):
			push_error("Native rune response mismatch: %s" % row)
			quit(1)
			return
	print("PASS ",source.cases.size()," native rune response admission/history cases")
	quit()
