extends SceneTree
const Markers = preload("res://scripts/lol2/hive_marker_runtime.gd")
const Conditions = preload("res://scripts/lol2/hive_condition_runtime.gd")
func _initialize() -> void: run.call_deferred()
func fixture(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_"+name+"_native.json"))
func run() -> void:
	var loaded := Markers.load_hive_executioner()
	assert(not loaded.has("error"))
	var bank: PackedByteArray = loaded.bank
	# A resumed marker differs from the constructor0. Save/load must preserve it.
	var saved := Markers.checkpoint(bank,7,9,1234)
	assert(not saved.has("error"))
	var original: Dictionary = saved.checkpoint.duplicate(true)
	var wire = JSON.parse_string(JSON.stringify(saved.checkpoint))
	var restored := Markers.restore(bank,wire)
	assert(not restored.has("error") and restored.checkpoint == original)
	var skip := Markers.apply_command(bank,wire,65535,15)
	assert(not skip.has("error") and not skip.applied and skip.checkpoint == original)
	var clear := Markers.apply_command(bank,wire,65535,0)
	assert(not clear.has("error") and clear.applied and clear.checkpoint.selected == null)
	assert(clear.checkpoint.actor_marker == 7 and clear.checkpoint.counter == 0)
	var again := Markers.restore(bank,JSON.parse_string(JSON.stringify(clear.checkpoint)))
	assert(not again.has("error") and again.checkpoint.selected == null)
	var select := Markers.apply_command(bank,again.checkpoint,12,0)
	assert(not select.has("error") and select.checkpoint.selected == 12 and select.checkpoint.actor_marker == 7)
	assert(saved.checkpoint == original and wire.actor_marker == 7 and wire.selected == 9 and wire.counter == 1234)
	var other := bank.duplicate();other[0] = other[0]^255
	assert(Markers.restore(other,wire).has("error"))
	for field in original:
		var invalid := original.duplicate(true);invalid.erase(field)
		assert(Markers.restore(bank,invalid).has("error"))
	for pair in [["version",true],["version",2],["actor_marker",60],["selected",60],["counter",65536],["bank_sha256",null]]:
		var invalid := original.duplicate(true);invalid[pair[0]] = pair[1]
		assert(Markers.restore(bank,invalid).has("error"))
	assert(Markers.apply_command(bank,wire,60,0).has("error"))
	var actor: Dictionary = fixture("actor_conditions")[0]
	var player: Dictionary = fixture("player_conditions")[0].context
	var remaining: Dictionary = fixture("remaining_conditions")[0].context
	var core := Conditions.new()
	var before := core.evaluate_with_marker_bank(actor.stats,6,actor,player,remaining,[0,0],bank,7,9,0x127f)
	var after := core.evaluate_with_marker_checkpoint(actor.stats,6,actor,player,remaining,[0,0],bank,wire,0x127f)
	assert(not before.has("error") and before == after)
	assert(core.evaluate_with_marker_checkpoint(actor.stats,6,actor,player,remaining,[0,0],other,wire,0x127f).has("error"))
	print("PASS: marker checkpoint JSON round trips, resume/clear/skip transitions, foreign-bank rejection and stable AI results")
	quit(0)
