extends RefCounted
## Museum prop153 "7-Long arm" pedestal and floor trap (scripts/lol2/museum_long_arm_source.json).
## walkway: local25, set by the walkway regions' first contact (it also enables prop153, property 0x0D).
## stage0 = on the pedestal; stage1 = prop108 timer running (group2656 ran, or a chamber re-arm);
## stage2 = timer expired. pending = the expired timer's form2 request is still owed (modern forced-form adapter:
## it is applied once no transition is active and requests are admitted, so it is never silently lost).
const ITEM := "museum:prop153:Long_arm"
const TIMER := 150.0/60.0 # Adapter: prop108 kind2 word 0x96 as 60/s ticks.
const FORM := 2
const FORM_SECONDS := 90.0 # Adapter: source duration byte 0; shared timed-form range is 60..150.
const KEYS := ["version","stage","elapsed","walkway","pending"]

static func initial() -> Dictionary: return {"version":1,"stage":0,"elapsed":0.0,"walkway":false,"pending":false}

static func validate(value: Variant, collected: Variant = null) -> String:
	if not value is Dictionary or value.size() != KEYS.size(): return "Invalid Long arm packet."
	for key in KEYS:
		if not value.has(key): return "Invalid Long arm packet."
	for key in ["version","stage"]:
		var n = value.get(key)
		if not (n is int or n is float) or n != int(n): return "Invalid Long arm integer."
	if value.version != 1 or value.stage < 0 or value.stage > 2: return "Invalid Long arm stage."
	if not value.walkway is bool or not value.pending is bool: return "Invalid Long arm flag."
	var elapsed = value.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0: return "Invalid Long arm timer."
	if (int(value.stage) != 1 and elapsed != 0) or (int(value.stage) == 1 and elapsed >= TIMER): return "Inconsistent Long arm timer."
	if (value.pending and int(value.stage) != 2) or (int(value.stage) > 0 and not value.walkway): return "Inconsistent Long arm stage."
	if collected == null: return ""
	if not collected is Array or collected.count(ITEM) > 1: return "Invalid Long arm inventory."
	# The pedestal grant is one-time and Museum items cannot be discarded.
	if (int(value.stage) > 0) != (ITEM in collected): return "Inconsistent Long arm pickup."
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	return {"version":1,"stage":int(value.stage),"elapsed":float(value.elapsed),"walkway":bool(value.walkway),"pending":bool(value.pending)}

static func floors_dropped(state: Dictionary) -> bool: return int(state.stage) > 0

## Group2656 (empty hand only, prop153 enabled by walkway contact). Returns false when refused.
static func take(state: Dictionary, inventory: Dictionary) -> bool:
	if int(state.stage) != 0 or not state.walkway or inventory.hand != "" or ITEM in inventory.collected: return false
	inventory.collected.append(ITEM)
	inventory.hand = ITEM
	state.stage = 1
	state.elapsed = 0.0
	return true

## Advances prop108's timer; true exactly once per run when group2052 fires (the form2 request becomes owed).
static func advance(state: Dictionary, delta: float) -> bool:
	if int(state.stage) != 1 or not is_finite(delta) or delta <= 0: return false
	state.elapsed = float(state.elapsed) + delta
	if state.elapsed < TIMER: return false
	state.stage = 2
	state.elapsed = 0.0
	state.pending = true
	return true

## Regions171/176 (op14 op3 on prop108): restart the timer while no request is owed and the player is not tiny.
## Adapter: source predicate99 needs GV_LUTHER_FORM != 0; the port also re-arms a human player, because the
## Museum has no periodic curse that would otherwise make a human nonhuman again inside the sealed chamber.
static func rearm(state: Dictionary, form: int) -> bool:
	if int(state.stage) != 2 or state.pending or form == FORM: return false
	state.stage = 1
	state.elapsed = 0.0
	return true
