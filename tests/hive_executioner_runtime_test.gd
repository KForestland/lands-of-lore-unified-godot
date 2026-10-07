extends SceneTree
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void:
	var owner := Owner.new()
	var attack := Attack.new()
	var stream := attack.checkpoint()
	stream.selector = 12;stream.frame = 6;stream.timer = 0
	stream.flags = 1;stream.base = 100;stream.gate = true;stream.result_count = 255;stream.result_total = 65530
	var actor := {"ac":1,"ad":255,"b4":0,"b5":0,"b7":1,"b9":0,"target":0x22574}
	assert(owner.restore({"version":1,"actor":actor,"attack":stream}).is_empty())
	var initial := owner.checkpoint()
	var feedback := func(_request):
		assert(owner.checkpoint().is_empty())
		assert(owner.advance(1).has("error"))
		assert(not owner.restore(initial).is_empty())
		return {"remaining":100,"loss":50,"percentage":10}
	var hit := owner.advance(1,feedback)
	assert(not hit.has("error"))
	var after := owner.checkpoint()
	assert(after.actor.ad == 0 and after.attack.result_count == 0)
	assert(after.attack.result_total == 4 and after.actor.b7 == after.attack.flags)
	# Nonterminal action5 must retain feedback when the decision runs next.
	var helpers := {"vertical":func(_s,_m):return 4,"random":func(_s,_m):return 0,"behavior":func(_s):pass}
	assert(not owner.decide({"action":5,"terminal":false},helpers).has("error"))
	assert(owner.checkpoint() == after)
	var exported_decision := owner.decide({"action":5,"terminal":false},helpers)
	exported_decision.state.ad = 99
	assert(owner.checkpoint() == after)
	assert(owner.decide({"action":0,"terminal":true},{}).has("error"))
	assert(owner.checkpoint() == after)
	var resumed := Owner.new()
	assert(resumed.restore(JSON.parse_string(JSON.stringify(after))).is_empty())
	for delta in [1024,1024,1024,1024]:
		assert(owner.advance(delta) == resumed.advance(delta))
	assert(owner.checkpoint() == resumed.checkpoint())
	var baseline := owner.checkpoint()
	for field in ["ad","b7","b4","b5"]:
		var bad := baseline.duplicate(true)
		bad.actor[field] = int(bad.actor[field]) ^ (8 if field == "b4" else (2 if field == "b5" else 1))
		assert(not owner.restore(bad).is_empty())
		assert(owner.checkpoint() == baseline)
	# Invalid feedback cannot partially change the actor or animation.
	assert(owner.restore(initial).is_empty())
	assert(owner.advance(1,func(_r):return {"remaining":0,"loss":50,"percentage":10}).has("error"))
	assert(owner.checkpoint().actor == initial.actor and owner.checkpoint().attack == initial.attack)
	var copy := owner.checkpoint();copy.actor.ad = 123
	assert(owner.checkpoint().actor == initial.actor and owner.checkpoint().attack == initial.attack)
	# Direction follows B4bit3 when a synchronous behavior callback changes it.
	helpers.behavior = func(s):s.b4 |= 8
	var reverse_state := initial.duplicate(true);reverse_state.actor.b7 = 0;reverse_state.attack.flags = 0
	assert(owner.restore(reverse_state).is_empty())
	assert(not owner.decide({"action":0,"terminal":true},helpers).has("error"))
	assert(owner.checkpoint().attack.reverse)
	print("PASS: executioner actor/frame feedback ownership, JSON continuation, atomic rejection and callback guards")
	quit(0)
