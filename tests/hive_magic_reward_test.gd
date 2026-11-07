extends SceneTree
const Reward = preload("res://scripts/lol2/hive_magic_reward.gd")
func _initialize():
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_magic_reward_native.json"))
	for row in rows:
		var before: Dictionary = row.player.duplicate(true)
		for field in ["experience","level","maximum","mana"]: row.expected.state[field] = int(row.expected.state[field])
		row.expected.draws_used = int(row.expected.draws_used)
		var result := Reward.apply_reward(row.player,row.award,row.draws)
		if result != row.expected or row.player != before:
			push_error("Magic reward differs from native fixture: "+str(row)+" actual: "+str(result))
			quit(1)
			return
	var player := {"experience":249,"level":1,"maximum":30,"mana":7}
	for draws in [[],[-1],[160],[1.5]]:
		if not Reward.apply_reward(player,200,draws).has("error"):
			push_error("Invalid reward draw admitted")
			quit(1)
			return
	print("PASS: ",rows.size()," native magic experience/mana cases and invalid-draw rollback")
	quit()
