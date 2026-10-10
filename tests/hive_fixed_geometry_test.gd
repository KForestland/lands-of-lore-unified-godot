extends SceneTree
const Geometry = preload("res://scripts/lol2/hive_condition_geometry.gd")
const Runtime = preload("res://scripts/lol2/hive_condition_runtime.gd")
func _initialize() -> void: run.call_deferred()
func fixture(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_"+name+"_native.json"))
func run() -> void:
	var vectors = fixture("fixed_geometry")
	for row in vectors:
		var result := Geometry.distance9(row.actor_fixed,row.point,row.rounding_mode)
		assert(not result.has("error") and result.distance == row.distance)
		assert(result.integer_invalid == row.integer_invalid)
	var core := Runtime.new()
	var actor: Dictionary = fixture("actor_conditions")[0]
	var player: Dictionary = fixture("player_conditions")[0].context
	var remaining: Dictionary = fixture("remaining_conditions")[0].context.duplicate(true)
	remaining.distance9 = -2147483648
	remaining.radius9 = 255
	var original := remaining.duplicate(true)
	var region := {"coordinates":[0,0],"radius":1}
	for fixed in [2097151,2097152,2097153]:
		var result := core.evaluate_with_regions(actor.stats,6,actor,player,remaining,[fixed,0],region,null,0)
		assert(not result.has("error"))
		assert((9 in result.conditions) == (fixed <= 2097152))
		assert(41 not in result.conditions and not result.distance9_integer_invalid)
	# Preserve the downstream signed subtraction, even for FISTP indefinite.
	for radius in [0,1]:
		region.radius = radius
		var result := core.evaluate_with_regions(actor.stats,6,actor,player,remaining,[-2147483648,0],region,null,0)
		assert(not result.has("error") and result.distance9_integer_invalid)
		assert((9 in result.conditions) == (radius == 0))
	assert(remaining == original)
	for invalid in [null,{},false,{"coordinates":[0,0],"radius":256}]:
		assert(core.evaluate_with_regions(actor.stats,6,actor,player,remaining,[0,0],invalid,null,0).has("error"))
	for invalid in [null,[],[0],[0,true],[0,2147483648],[0,-2147483649]]:
		assert(Geometry.distance9(invalid,[0,0],0).has("error"))
	for invalid in [null,[],[0],[0,true],[0,32768],[0,-32769]]:
		assert(Geometry.distance9([0,0],invalid,0).has("error"))
	for invalid in [-1,4,true,null,0.5]:
		assert(Geometry.distance9([0,0],[0,0],invalid).has("error"))
	print("PASS: 4096 native fixed distances; inclusive condition9 boundary, integer-invalid propagation and validation")
	quit(0)
