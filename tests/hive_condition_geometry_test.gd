extends SceneTree
const Geometry = preload("res://scripts/lol2/hive_condition_geometry.gd")
const Runtime = preload("res://scripts/lol2/hive_condition_runtime.gd")
func _initialize() -> void: run.call_deferred()
func fixture(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_"+name+"_native.json"))
func run() -> void:
	var vectors = fixture("condition_geometry")
	for row in vectors:
		var result := Geometry.distance41(row.actor_fixed,row.point,row.rounding_mode)
		assert(not result.has("error") and result.distance == row.distance)
	var core := Runtime.new()
	var actor: Dictionary = fixture("actor_conditions")[0]
	var player: Dictionary = fixture("player_conditions")[0].context
	var remaining: Dictionary = fixture("remaining_conditions")[0].context.duplicate(true)
	remaining.size_definition = 0
	# Deliberately stale supplied values must be replaced by bound geometry.
	remaining.geometry41_enabled = false
	remaining.distance41 = -2147483648
	remaining.radius41 = 255
	var original := remaining.duplicate(true)
	for units in [31,32,33]:
		var point := {"coordinates":[0,0],"radius":1}
		var result := core.evaluate_with_geometry(actor.stats,6,actor,player,remaining,[units*65536,0],point,0)
		assert(not result.has("error"))
		assert((41 in result.conditions) == (units < 32))
		assert(not result.live_context_bound)
	assert(remaining == original)
	var absent := core.evaluate_with_geometry(actor.stats,6,actor,player,remaining,null,null,null)
	assert(not absent.has("error") and 41 not in absent.conditions)
	for invalid in [null,[],[0],[0,true],[0,2147483648],[0,-2147483649]]:
		assert(Geometry.distance41(invalid,[0,0],0).has("error"))
	for invalid in [null,[],[0],[0,true],[0,32768],[0,-32769]]:
		assert(Geometry.distance41([0,0],invalid,0).has("error"))
	for invalid in [-1,4,true,null,0.5]:
		assert(Geometry.distance41([0,0],[0,0],invalid).has("error"))
	for invalid in [false,{}, {"coordinates":[0,0],"radius":256}]:
		assert(core.evaluate_with_geometry(actor.stats,6,actor,player,remaining,[0,0],invalid,0).has("error"))
	print("PASS: 1024 native geometry vectors; strict condition41 admission, absent point and validation")
	quit(0)
