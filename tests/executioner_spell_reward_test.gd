extends SceneTree
const Planner = preload("res://scripts/lol2/executioner_spell_reward.gd")
func fail(message: String) -> void:
	push_error(message)
	quit(1)
func _initialize():
	var native: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/executioner-spell-rewards.native.json"))
	var keys: Array = native["keys"]
	var bases: Array = native.bases
	for values in native.rows:
		var row := {}
		for i in keys.size(): row[keys[i]] = values[i]
		var request := {"mode":int(row.mode),"effect":int(row.effect),"scale":int(row.scale),"loss":int(row.loss),"remaining":int(row.remaining),"special":int(row.special)}
		var player := {"fighting_level":int(row.fighting_level),"magic_level":int(row.magic_level)}
		var before := [request.duplicate(),player.duplicate()]
		var result := Planner.plan(request,player,bases)
		var marker := -1 if int(row.marker)==255 else int(row.marker)
		if result.has("error") or result.bank!=row.bank or int(result.award)!=int(row.award) or int(result.marker)!=marker or before!=[request,player]:
			return fail("Spell reward differs from native D0BEC: "+str(row)+" actual: "+str(result))
	var binding: Dictionary = native.binding
	if int(binding.actor)!=36 or int(binding.scale)!=8: return fail("Executioner scale binding changed.")
	var spell := {"mode":2,"effect":20,"scale":int(binding.scale),"loss":8,"remaining":8,"special":0}
	var magic := Planner.plan(spell,{"fighting_level":1,"magic_level":1},bases)
	var melee := Planner.plan(spell.merged({"mode":1},true),{"fighting_level":1,"magic_level":1},bases)
	if magic.bank!="magic" or melee.bank!="fighting" or int(melee.award)!=20: return fail("Actor36 bank split mismatch: "+str([magic,melee]))
	if Planner.plan(spell.merged({"loss":0},true),{"fighting_level":1,"magic_level":1},bases).bank!="none": return fail("Zero loss admitted.")
	for bad in [[spell.merged({"scale":0},true),bases],[spell.merged({"mode":1.5},true),bases],[spell,bases.slice(1)],[spell.merged({"loss":-1},true),bases]]:
		if not Planner.plan(bad[0],{"fighting_level":1,"magic_level":1},bad[1]).has("error"): return fail("Invalid spell reward input admitted: "+str(bad[0]))
	if not Planner.plan(spell,{"fighting_level":1},bases).has("error"): return fail("Missing magic level admitted.")
	print("PASS: ",native.rows.size()," native D0BEC fighting/magic reward cases; actor36 scale8 bank split")
	quit(0)
