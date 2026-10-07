extends SceneTree
const Bridge = preload("res://scripts/lol2/hive_executioner_action.gd")
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void:
	var attack := Attack.new()
	var draws: Array = []
	var helpers := {"vertical":func(_s,_m):return 4,"random":func(_s,m):
		draws.append(m)
		return 0,"behavior":func(_s):pass}
	for mode in range(4):
		for mask in range(256):
			var actor := {"b4":0,"b5":0,"b7":1|(mode<<1),"b9":0,"ad":0,"target":0,"ac":mask}
			for previous in [11,12]:
				var stream := attack.checkpoint()
				stream.selector = previous;stream.frame = 6;stream.timer = 513
				assert(attack.restore(stream).is_empty())
				var expected := Attack.action_selector(mask,mode)
				var result := Bridge.run(actor,{"action":0,"terminal":true},helpers,attack)
				assert(not result.has("error") and result.selections.size() == 1)
				assert(result.attack.selector == expected)
				assert(result.attack.frame == (6 if previous == expected else 0))
				assert(result.attack.timer == (513 if previous == expected else 0))
				assert(result.state.target == 0x22574 and actor.target == 0)
	assert(draws.size() == 2048)
	for maximum in draws: assert(maximum == 100)
	# Composed admitted selector11 reaches its source sound and damage frames.
	var stream := attack.checkpoint()
	stream.selector = 12;stream.frame = 6;stream.timer = 513
	stream.base = 100;stream.gate = true;stream.frozen = false
	assert(attack.restore(stream).is_empty())
	var actor := {"b4":0,"b5":0,"b7":1,"b9":0,"ad":3,"target":0,"ac":2}
	var result := Bridge.run(actor,{"action":0,"terminal":true},helpers,attack)
	assert(result.attack.selector == 11 and result.attack.result_count == 3)
	var events: Array = []
	for i in range(8): events.append_array(attack.advance_native(1 if i == 0 else 1024).events)
	assert(events.size() == 2 and events[0].type == "sound" and events[0].frame == 7 and events[0].id == 684)
	assert(events[1].type == "damage" and events[1].frame == 8 and events[1].amount == 50)
	# Busy actors do not select; B5bit1 reaches the stream freeze gate.
	actor.b5 = 3
	var before := attack.checkpoint()
	result = Bridge.run(actor,{"action":0,"terminal":true},helpers,attack)
	assert(result.selections.is_empty() and result.attack.frame == before.frame and result.attack.frozen)
	assert(attack.advance_native(1024).events.is_empty())
	before = attack.checkpoint()
	actor.ac = -1
	assert(Bridge.run(actor,{"action":0,"terminal":true},helpers,attack).has("error"))
	assert(attack.checkpoint() == before)
	print("PASS: 2048 admission/selector/animation compositions, frame events and freeze propagation")
	quit(0)
