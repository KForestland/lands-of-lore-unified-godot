extends SceneTree
const Markers = preload("res://scripts/lol2/hive_marker_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_marker_native.json"))
	for row in rows:
		var record := PackedByteArray(row.record)
		var before := record.duplicate()
		var result := Markers.initial_actor_marker(record)
		assert(not result.has("error") and result.marker == row.marker)
		assert(record == before)
	for invalid in [null,[],PackedByteArray(),PackedByteArray([0])]:
		assert(Markers.initial_actor_marker(invalid).has("error"))
	var loaded := Markers.load_hive_executioner()
	assert(not loaded.has("error") and loaded.actor_marker == 0 and loaded.count == 60)
	var records := Markers.resolve_geometry(loaded.bank,loaded.actor_marker,null)
	assert(not records.has("error") and records.point41 == null)
	print("PASS:512 native placement marker initializations and source-backed executioner loading")
	quit(0)
