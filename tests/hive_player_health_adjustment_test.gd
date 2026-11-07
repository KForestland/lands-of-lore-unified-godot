extends SceneTree
const Health = preload("res://scripts/lol2/hive_player_health_adjustment.gd")
func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_health_adjustment_native.json"))
	assert(fixture.adjustments.size()==4096 and fixture.composed.size()==1356)
	for row in fixture.adjustments:
		var result := Health.adjust(row,row.amount)
		assert(result.current==int(row.expected.current) and result.display==row.expected.display)
	for row in fixture.composed:
		var before: Dictionary = row.duplicate(true)
		var result := Health.finalize(row,row.result)
		assert(result.current==int(row.expected.current))
		assert(result.displays.size()==row.expected.displays.size())
		for i in range(result.displays.size()): assert(result.displays[i]==int(row.expected.displays[i]))
		assert(row==before)
	var context := {"current":100,"maximum":150,"flags229":0}
	assert(Health.finalize(context,{"loss":4,"remaining":96,"virtual84":[2]}).current==96)
	assert(Health.finalize(context,{"loss":0,"remaining":100,"virtual84":[2,2]}).current==104)
	for invalid in [null,true,-1,8193,0.5]: assert(Health.adjust(context,invalid).has("error"))
	assert(Health.finalize(context,{"loss":100,"remaining":0,"virtual84":[]}).has("error"))
	assert(Health.finalize(context,{"loss":4,"remaining":100,"virtual84":[]}).has("error"))
	print("PASS:4096 native health adjustments and1356 damage-result compositions")
	quit()
