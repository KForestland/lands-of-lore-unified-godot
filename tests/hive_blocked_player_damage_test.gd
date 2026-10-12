extends SceneTree
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
const Entry = preload("res://scripts/lol2/hive_player_damage_entry.gd")
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")

func equivalent(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b

func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_blocked_player_damage_native.json"))
	assert(fixture.size()==1024)
	for row in fixture:
		var attack := Attack.new();var initial: Dictionary = row.initial.duplicate(true);initial.version=2
		assert(attack.restore(initial).is_empty())
		var calls: Array = []
		var resolver := func(event):
			calls.append(event)
			return Entry.resolve(event,{"global223d4":row.global223d4,"flags228":8,"current":100})
		var result := attack.advance_native(row.delta,resolver)
		assert(equivalent(result,row.expected))
		assert(calls.size()==int(row.handler_calls))
		assert(attack.checkpoint().result_total==65530 and attack.checkpoint().result_count==250)
	var actor := {"ac":1,"ad":0,"b4":0,"b5":0,"b7":1,"b9":0,"target":0}
	var target := {"attacker_heading":32768,"player_heading":32768,"guard":1,"mode":1,"scalar":0,"current":100,"descriptors":[],"global223d4":1,"flags228":8}
	var owner := Owner.new()
	assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
	assert(owner.advance(32767).events.back().type=="terminal")
	var helpers := {"vertical":func(_s,_m):return 4,"random":func(_s,_m):return 0,"behavior":func(_s):pass}
	assert(not owner.decide_current({},helpers).has("error"))
	assert(owner.bind_player_damage(target).is_empty())
	var result := owner.advance_with_player_damage(6145)
	assert(result.player_damage.current==100 and owner.checkpoint().actor.ad==0)
	var saved := owner.checkpoint();var resumed := Owner.new()
	assert(resumed.restore(JSON.parse_string(JSON.stringify(saved))).is_empty() and resumed.checkpoint()==saved)
	target.global223d4=0
	assert(owner.bind_player_damage(target).is_empty());saved=owner.checkpoint()
	assert(owner.advance_with_player_damage(4096).has("error") and owner.checkpoint()==saved)
	assert(not Attack.validate_feedback({"loss":0,"remaining":1,"percentage":0,"callback":0}).is_empty())
	print("PASS:1024 native blocked-handler compositions, saved gates and zero-state rollback")
	quit()
