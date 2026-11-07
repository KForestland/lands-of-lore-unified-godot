extends RefCounted
## Cave prop83 shaft-lift chain (cave_prop83_lift_source.json), saved by the cave host as "prop83_lift".
##  state 0: hits are admitted (kind9 g108 melee / g124 Spark, which also writes local25); a hit starts sound 956.
##  When that sound finishes (kind8 value956) g146 runs: selector2, state1, then kind3 g264: the wall regions
##  1029..1033 open at once (speed0, relative -160) and the eight shaft floors start rising from -1000 to -290.
## Invariants: state0 has no lift and no opening; state1 is opened; the shaft rises only in state1.
const SHAFT_START := -1000.0
const SHAFT_TOP := -290.0
const SPEED := 5
const UNITS_PER_SPEED := 2.5

static func initial() -> Dictionary:
	return {"version":1,"state":0,"local25":0,"sound":0.0,"shaft":SHAFT_START,"opened":false}

static func _num(v: Variant, lo: float, hi: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) >= lo and float(v) <= hi
static func validate(value: Variant, sound_seconds: float) -> String:
	if not value is Dictionary or value.size() != 6 or value.get("version") != 1: return "Invalid prop83 lift state."
	for key in ["state","local25"]:
		var v = value.get(key)
		if not (v is int or v is float) or not (v == 0 or v == 1): return "Invalid prop83 lift state."
	if not _num(value.get("sound"), 0.0, sound_seconds) or not _num(value.get("shaft"), SHAFT_START, SHAFT_TOP) or not value.get("opened") is bool: return "Invalid prop83 lift state."
	if int(value.state) == 0 and (bool(value.opened) or float(value.shaft) != SHAFT_START): return "Shaft lift before prop83's chain."
	if int(value.state) == 1 and (not bool(value.opened) or float(value.sound) != 0.0): return "prop83 chain incomplete."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	return {"version":1,"state":int(value.state),"local25":int(value.local25),"sound":float(value.sound),"shaft":float(value.shaft),"opened":bool(value.opened)}

## kind9 hit at owner state0 (any admitted context; durability 2 is already <= threshold 9). Returns true when the
## source group ran (sound 956 started).
static func hit(state: Dictionary, group: int, sound_seconds: float) -> bool:
	if int(state.state) != 0 or float(state.sound) > 0.0: return false
	if group == 124: state.local25 = 1
	state.sound = sound_seconds
	return true

## Advances the sound (kind8 at its end -> g146 -> g264) and the shaft floor. Returns true on a visible change.
static func advance(state: Dictionary, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0: return false
	var changed := false
	var left := delta
	# Sound time is consumed first; only the remainder after the kind8 transition lifts the shaft.
	if float(state.sound) > 0.0:
		var used: float = minf(float(state.sound), left)
		state.sound = float(state.sound) - used
		left -= used
		if float(state.sound) == 0.0 and int(state.state) == 0:
			state.state = 1
			state.opened = true
			changed = true
	if left > 0.0 and int(state.state) == 1 and float(state.shaft) < SHAFT_TOP:
		state.shaft = minf(float(state.shaft) + SPEED * UNITS_PER_SPEED * left, SHAFT_TOP)
		changed = true
	return changed
