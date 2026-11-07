extends SceneTree
const Decision=preload("res://scripts/lol2/dawn_ai_decision.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_decision_native.json"))
	var decision:=Decision.new()
	assert(decision.configure_source().is_empty())
	assert(data.rows.size()==280)
	for row in data.rows:
		var context={"w88":800,"mana":row.mana,"check_cost":1,"target":0x22574,"seen":1,"b7":0,"distance":0,"exclusive":row.exclusive,"active":[],"write_reason":1}
		var before: Dictionary=row.state.duplicate(true)
		var result:=decision.decide(row.state,row.stats,context,row.rng)
		assert(not result.has("error"),str(row,result))
		for field in row.expected: assert(result.state[field]==row.expected[field],str(field,row,result))
		assert(result.accepted==row.accepted,str(row,result))
		assert(result.rng_requested==("0xaae0a" in row.calls),str(row,result))
		assert(row.state==before)
		# JSON save/restore of the input yields the same native decision.
		var loaded=JSON.parse_string(JSON.stringify(row.state))
		assert(decision.decide(loaded,row.stats,context,row.rng)==result)
	assert(not decision.configure({}).is_empty())
	print("PASS:280 composed native Dawn decisions; AI/mana gates, goal/action/spell ordering, admission and JSON continuation")
	quit()
