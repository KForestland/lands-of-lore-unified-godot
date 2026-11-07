extends SceneTree
## Pure prop83 lift timing: sound time is consumed before any lift (exact boundary opens with zero lift; the
## remainder only lifts), one large step equals many split steps, the top clamps, invalid states are rejected.
const State = preload("res://scripts/lol2/cave_prop83_lift_state.gd")
func _initialize() -> void:
	var rate := State.SPEED * State.UNITS_PER_SPEED
	var s := State.initial(); State.hit(s, 108, 1.0)
	State.advance(s, 1.0)
	assert(int(s.state) == 1 and s.opened and float(s.sound) == 0.0 and float(s.shaft) == State.SHAFT_START, "exact boundary lifted: %s" % [s])
	s = State.initial(); State.hit(s, 108, 1.0)
	State.advance(s, 1.5)
	assert(absf(float(s.shaft) - (State.SHAFT_START + 0.5 * rate)) < 1e-9, "remainder: %s" % [s])
	s = State.initial(); State.hit(s, 124, 1.0)
	State.advance(s, 0.4)
	assert(int(s.state) == 0 and int(s.local25) == 1 and absf(float(s.sound) - 0.6) < 1e-9 and float(s.shaft) == State.SHAFT_START, "mid-sound: %s" % [s])
	for total in [0.557, 3.0, 20.0, 70.0]:
		var big := State.initial(); State.hit(big, 108, 0.557); State.advance(big, total)
		var split := State.initial(); State.hit(split, 108, 0.557)
		var n := int(round(total / 0.0371)) + 1
		for i in n: State.advance(split, total / n)
		assert(int(big.state) == int(split.state) and big.opened == split.opened and absf(float(big.shaft) - float(split.shaft)) < 1e-6 and absf(float(big.sound) - float(split.sound)) < 1e-9, "split %f: %s vs %s" % [total, big, split])
	var top := State.initial(); State.hit(top, 108, 0.5); State.advance(top, 1000.0)
	assert(float(top.shaft) == State.SHAFT_TOP and State.validate(top, 0.5).is_empty())
	var bad := State.initial(); bad.shaft = -500.0
	assert(not State.validate(bad, 0.557).is_empty())
	bad = State.initial(); bad.state = 1
	assert(not State.validate(bad, 0.557).is_empty())
	bad = State.initial(); bad.sound = 0.9
	assert(not State.validate(bad, 0.557).is_empty())
	print("PASS cave_prop83_lift_state: exact sound boundary (no lift), remainder-only lift, large == split steps, clamp, negatives")
	quit()
