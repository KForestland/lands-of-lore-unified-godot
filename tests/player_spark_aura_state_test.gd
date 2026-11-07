extends SceneTree
const State = preload("res://scripts/lol2/player_spark_aura_state.gd")
func _initialize() -> void:
	var state := State.initial()
	State.extend(state)
	assert(state.timer == 600<<16)
	var coarse := state.duplicate(true)
	var fine := state.duplicate(true)
	var a := State.advance(coarse,5)
	var pulses := 0
	for i in 300: pulses += int(State.advance(fine,1.0/60.0).pulses)
	assert(a.pulses == pulses and absi(int(coarse.timer)-int(fine.timer)) <= 1)
	State.extend(coarse)
	assert(absi(int(coarse.timer)-(900<<16)) <= 1)
	var snapshot := State.canonical(JSON.parse_string(JSON.stringify(coarse)))
	assert(snapshot == coarse)
	assert(State.advance(coarse,15.01).expired and coarse.timer == 0)
	assert(not State.advance(coarse,1).expired)
	var draws := {}
	for i in 128: draws[State.draw_effect(state)] = true
	assert(draws.size() == 4 and draws.has(20) and draws.has(23))
	state.area = "res://scenes/lol2/hive_review.tscn"
	state.bolts = [{"target":"executioner36","effect":23,"position":[1.0,2.0,3.0],"life":2.0}]
	assert(State.validate(state).is_empty())
	assert(State.canonical(JSON.parse_string(JSON.stringify(state))) == state)
	for pair in [["timer",-1],["timer",1.5],["fraction",1.0],["pulse",NAN],["area","elsewhere"],["seed",true]]:
		var bad := state.duplicate(true)
		bad[pair[0]] = pair[1]
		assert(not State.validate(bad).is_empty())
	for pair in [["effect",24],["target","unknown"],["position",[INF,0,0]],["life",0]]:
		var bad := state.duplicate(true)
		bad.bolts[0][pair[0]] = pair[1]
		assert(not State.validate(bad).is_empty())
	if "--state-only" not in OS.get_cmdline_user_args():
		var Magic = load("res://scripts/lol2/hive_magic_reward.gd")
		var source: Dictionary = load("res://scripts/lol2/player_magic_state.gd").initial()
		source.spark_aura = state
		assert(Magic.restore(JSON.parse_string(JSON.stringify(source))).checkpoint.spark_aura == state)
		var reward: Dictionary = Magic.award_checkpoint(source,1,[])
		assert(not reward.has("error") and reward.checkpoint.spark_aura == state,"XP must preserve in-flight effect")
	print("PASS Spark aura clock, extension, pulse partition, saved RNG/bolts and malformed packet rejection; reward integration=" + str("--state-only" not in OS.get_cmdline_user_args()))
	quit()
