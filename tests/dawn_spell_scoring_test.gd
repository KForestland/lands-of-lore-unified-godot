extends SceneTree
const Scoring=preload("res://scripts/lol2/hive_ai_spell_choice.gd")
func _initialize() -> void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell_scores_native.json"))
	var scorer:=Scoring.new()
	assert(fixture.rows.size()==228)
	for row in fixture.rows:
		assert(scorer.configure(row.get("table",fixture.profile)).is_empty())
		var result:=scorer.score(row.stats,row.goal)
		assert(not result.has("error"),str(result))
		for field in ["scores","contributors","candidates","maximum"]:
			if result[field] is Array:
				assert(result[field].size()==row.expected[field].size())
				for i in range(result[field].size()): assert(result[field][i]==row.expected[field][i],str(field,i,row.goal))
			else: assert(result[field]==row.expected[field],str(field,row.goal))
	assert(scorer.score([],0).has("error"))
	assert(scorer.score(fixture.rows[0].stats,14).has("error"))
	assert(not scorer.configure({}).is_empty())
	print("PASS:228 native spell scorings; signed weights, goal exclusions, zero-score bias skip and ordered positive candidates")
	quit()
