extends RefCounted
## Cave Aloe use (handler9) and the native pending-heal tick D44F4, in source units.
## Replayed by tools/verify_cave_aloe_use.py; fixtures in docs/cave-aloe-use.json.
const MASK := 0xffffffff
const HEAL := 5
const GESTURE_STATE := 0
const GESTURE_TIMER := 30
const RATE := 30
const CLOCK_UNIT := 4096

## Handler9 after shared admission 7E968. Event must be 1. consume_gate mirrors 223D4:
## when set the item stays held, but +5 and the gesture still happen.
static func use(pending: int, event: int = 1, consume_gate: bool = false) -> Dictionary:
	if event != 1:
		return {"result": 0, "consumed": false, "pending": pending, "gesture": false}
	return {"result": 1, "consumed": not consume_gate, "pending": (pending + HEAL) & MASK, "gesture": true}

## One player update. State keys: health, maximum, base (byte +163), pending, pause (+17D),
## hold (+227 bit5), frac (clock +505), delta (clock +4B6). Returns health/base/pending/ui.
static func tick(s: Dictionary) -> Dictionary:
	var health: int = s.health
	var base: int = s.base
	var pending: int = s.pending
	var ui := false
	if not s.hold and pending == 0 and s.pause == 0:
		base = health & 0xff
	if health != 0 and pending != 0 and s.pause == 0:
		var n: int = (pending * RATE) & MASK
		var a: int = (((int(s.frac) & 0xfff) * n) & MASK) >> 12
		var b: int = ((((int(s.frac) + int(s.delta)) & 0xfff) * n) & MASK) >> 12
		health = (health + (((n - (a - b)) & MASK) if a > b else b - a)) & MASK
		if int(s.maximum) < health:
			pending = 0
			health = s.maximum
		elif ((base + pending) & MASK) < health:
			base = (base + pending) & 0xff
			pending = 0
		ui = true
	return {"health": health, "base": base, "pending": pending, "ui": ui}

## Modern adapter: advance by clock units (native CLOCK_UNIT per unresolved time unit).
## Carries frac; callers keep a per-player Dictionary with the tick() keys.
static func advance(s: Dictionary, delta: int) -> Dictionary:
	var state := s.duplicate()
	state.delta = clampi(delta, 0, CLOCK_UNIT - 1)
	var after := tick(state)
	state.merge(after, true)
	state.frac = (int(s.frac) + state.delta) & MASK
	return state
