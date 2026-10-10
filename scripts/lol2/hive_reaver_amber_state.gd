extends RefCounted
## Hive Reaver alcove (control121), its ceiling-collapse trap and the Amber vein (control123)
## (scripts/lol2/hive_reaver_amber_source.json).
##  reaver: state 0 sword in the wall / 2 taken (state1 is transient: the selector1 callback writes state2 at once
##          and resets the timer). The timer (source 5..10 s, adapter 7.5 s) then fires once: region365 floor -> -234.
##  collapse: active surface movers {"region:surface": target, speed}; current heights. Region movement events
##          (start 0/1 floor up/down, 2/3 ceiling up/down; end 4/5/6/7) run the source kind11 chain groups, whose
##          op196 commands start further movers. Movers advance at speed x 2.5 units/s; a blocked mover waits.
##  amber:  state 0/1/2 harvestable (selector = state), 5 empty (selector3). Harvest at 2 resets the timer; at
##          expiry (source 32..144 s, adapter 88 s) an empty vein regrows to state2.
##  pillars: corridor support pillars 401/426/676/725 (hive_reaver_pillars_source.json), state 0->1->2 per landed
##          hit; every hit also runs region365 floor -> -234 (speed20), the Reaver timer's nudge, so a pillar hit can
##          start the collapse before the sword is taken. The sword is lost only once the alcove (region364) seals.
##          Saves without pillars (older format) load with all pillars at 0.
const Items = preload("res://scripts/lol2/hive_amber_items.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const REAVER := "hive:control121:Reaver_of_GO"
const REAVER_DELAY := 7.5
const AMBER_REGROW := 88.0
const UNITS_PER_SPEED := 2.5
const ORIGINAL := {"floor":-235.0,"ceiling":-107.0}
const PILLARS := ["401","426","676","725"]
const ALCOVE := 364

static func source() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/hive_reaver_amber_source.json"))

static func pillar_source() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/hive_reaver_pillars_source.json"))

static func initial() -> Dictionary:
	return {"version":1,"reaver":{"state":0,"timer":0.0},"collapse":{"heights":{},"movers":{},"finished":false},"amber":{"state":0,"timer":0.0},"pillars":_pillars_initial()}

static func _pillars_initial() -> Dictionary:
	var out := {}
	for id in PILLARS: out[id] = 0
	return out

static func pillars_hit(state: Dictionary) -> bool:
	for id in PILLARS:
		if int(state.get("pillars", {}).get(id, 0)) > 0: return true
	return false

static func _num(v: Variant, lo: float, hi: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) >= lo and float(v) <= hi
static func _key_ok(key: Variant, src: Dictionary) -> bool:
	if not key is String or key.get_slice_count(":") != 2: return false
	return src.regions.has(key.get_slice(":", 0)) and key.get_slice(":", 1) in ["floor","ceiling"]

static func validate(value: Variant, src: Dictionary = {}) -> String:
	if src.is_empty(): src = source()
	if not value is Dictionary or not value.size() in [4, 5] or value.get("version") != 1: return "Invalid Hive Reaver/Amber state."
	if value.size() == 5:
		var p = value.get("pillars")
		if not p is Dictionary or p.size() != PILLARS.size(): return "Invalid Reaver pillars."
		for id in PILLARS:
			var v = p.get(id)
			if not (v is int or v is float) or float(v) != floorf(float(v)) or not int(v) in [0,1,2]: return "Invalid Reaver pillar state."
	var hit: bool = value.size() == 5 and pillars_hit(value)
	var r = value.get("reaver"); var c = value.get("collapse"); var a = value.get("amber")
	if not r is Dictionary or r.size() != 2 or not (r.get("state") is int or r.get("state") is float) or not int(r.state) in [0,2] or float(r.state) != floorf(float(r.state)): return "Invalid Reaver state."
	if not _num(r.get("timer"), 0.0, REAVER_DELAY): return "Invalid Reaver timer."
	if int(r.state) == 0 and float(r.timer) != 0.0: return "Reaver timer runs before the sword is taken."
	if not c is Dictionary or c.size() != 3 or not c.get("heights") is Dictionary or not c.get("movers") is Dictionary or not c.get("finished") is bool: return "Invalid collapse state."
	for key in c.heights:
		if not _key_ok(key, src) or not _num(c.heights[key], -235.0, -107.0): return "Invalid collapse height."
	for key in c.movers:
		var m = c.movers[key]
		if not _key_ok(key, src) or not m is Dictionary or m.size() != 2 or not _num(m.get("target"), -235.0, -107.0) or not _num(m.get("speed"), 1, 255): return "Invalid collapse mover."
		if not c.heights.has(key): return "Collapse mover without a height."
	if int(r.state) == 0 and (not c.heights.is_empty() or c.finished) and not hit: return "Collapse without the Reaver taken."
	if int(r.state) == 2 and float(r.timer) > 0 and not c.heights.is_empty() and not hit: return "Collapse before the Reaver timer."
	if not a is Dictionary or a.size() != 2 or not (a.get("state") is int or a.get("state") is float) or not int(a.state) in [0,1,2,5] or float(a.state) != floorf(float(a.state)): return "Invalid Amber state."
	if not _num(a.get("timer"), 0.0, AMBER_REGROW): return "Invalid Amber timer."
	if (int(a.state) == 5) != (float(a.timer) > 0): return "Amber timer disagrees with its state."
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	var out := initial()
	out.reaver = {"state":int(value.reaver.state),"timer":float(value.reaver.timer)}
	for key in value.collapse.heights: out.collapse.heights[key] = float(value.collapse.heights[key])
	for key in value.collapse.movers: out.collapse.movers[key] = {"target":float(value.collapse.movers[key].target),"speed":int(value.collapse.movers[key].speed)}
	out.collapse.finished = bool(value.collapse.finished)
	out.amber = {"state":int(value.amber.state),"timer":float(value.amber.timer)}
	for id in PILLARS: out.pillars[id] = int(value.get("pillars", {}).get(id, 0))
	return out

## Displayed selectors: Reaver 0 (sword) / 1 (empty); Amber 0..3 (state5 shows selector3).
static func reaver_selector(state: Dictionary) -> int: return 0 if int(state.reaver.state) == 0 else 1
static func amber_selector(state: Dictionary) -> int: return 3 if int(state.amber.state) == 5 else int(state.amber.state)

static func height(state: Dictionary, region: int, surface: String) -> float:
	return float(state.collapse.heights.get("%d:%s" % [region, surface], ORIGINAL[surface]))

## The alcove (region364) is sealed once its rising floor and falling ceiling meet (both -185 by the chain).
static func alcove_sealed(state: Dictionary) -> bool:
	return height(state, ALCOVE, "ceiling") - height(state, ALCOVE, "floor") < 0.5

## Empty-hand take (kind4 mode0 state0): one Reaver; state1 -> selector1 callback -> state2 with a fresh timer.
## Refused once the alcove has sealed (a pillar-started collapse before the take loses the optional sword).
static func take_reaver(state: Dictionary, collected: Array) -> bool:
	if int(state.reaver.state) != 0 or alcove_sealed(state) or REAVER in collected or collected.size() >= Catalog.MAX_CARRIED: return false
	collected.append(REAVER)
	state.reaver = {"state":2,"timer":REAVER_DELAY}
	return true

## Harvest (kind4 mode0 state0/1/2): one Amber from the pool; refused atomically when empty or full.
static func harvest_amber(state: Dictionary, collected: Array) -> String:
	var s := int(state.amber.state)
	if not s in [0,1,2] or collected.size() >= Catalog.MAX_CARRIED: return ""
	var id := Items.next_free(collected)
	if id.is_empty(): return ""
	collected.append(id)
	if s == 2: state.amber = {"state":5,"timer":AMBER_REGROW}
	else: state.amber.state = s + 1
	return id

## Starts one op196 mover and dispatches its start event (and any chained starts) immediately. A repeat request
## for a target already reached or already being approached changes nothing (no second chain dispatch).
static func _start(state: Dictionary, src: Dictionary, m: Dictionary) -> void:
	var key := "%d:%s" % [int(m.region), str(m.surface)]
	var current := height(state, int(m.region), str(m.surface))
	if float(m.target) == current: return
	if state.collapse.movers.has(key) and float(state.collapse.movers[key].target) == float(m.target): return
	state.collapse.heights[key] = current
	state.collapse.movers[key] = {"target":float(m.target),"speed":int(m.speed)}
	var up := float(m.target) > current
	_event(state, src, int(m.region), (0 if up else 1) + (2 if str(m.surface) == "ceiling" else 0))

## Landed hit on a corridor pillar (kind9 value2048): its state record (0->1, 1->2, 2 stays), then the
## unconditional region365 floor nudge. Returns false for an unknown pillar.
static func hit_pillar(state: Dictionary, src: Dictionary, pillars: Dictionary, id: String) -> bool:
	if not id in PILLARS: return false
	if not state.has("pillars"): state.pillars = _pillars_initial()
	state.pillars[id] = int(pillars.states[str(int(state.pillars[id]))].next)
	_start(state, src, pillars.trigger)
	return true

static func _event(state: Dictionary, src: Dictionary, region: int, event: int) -> void:
	for link in src.chain:
		if int(link.region) != region or int(link.event) != event: continue
		for m in link.movers: _start(state, src, m)
		if link.movers.is_empty(): state.collapse.finished = true

## Advances the Reaver timer, every mover (in key order, all due completions drained) and the Amber timer.
## blocked(key, next_height) -> bool lets the host stop a mover that an occupant does not fit under.
static func advance(state: Dictionary, delta: float, src: Dictionary, blocked: Callable = Callable()) -> bool:
	if not is_finite(delta) or delta <= 0: return false
	# Long steps are split so chained movers started by a completion receive the remaining time.
	var changed := false
	var left := delta
	while left > 0:
		var step := minf(left, 0.05)
		left -= step
		changed = _step(state, step, src, blocked) or changed
	return changed

static func _step(state: Dictionary, delta: float, src: Dictionary, blocked: Callable) -> bool:
	var changed := false
	if int(state.reaver.state) == 2 and float(state.reaver.timer) > 0:
		state.reaver.timer = maxf(float(state.reaver.timer) - delta, 0.0)
		if state.reaver.timer == 0.0:
			_start(state, src, src.reaver.trigger)
			changed = true
	var keys: Array = state.collapse.movers.keys()
	keys.sort()
	for key in keys:
		if not state.collapse.movers.has(key): continue
		var m: Dictionary = state.collapse.movers[key]
		var current: float = float(state.collapse.heights[key])
		var next: float = move_toward(current, float(m.target), float(m.speed) * UNITS_PER_SPEED * delta)
		if blocked.is_valid() and blocked.call(key, next): continue
		state.collapse.heights[key] = next
		changed = true
		if next == float(m.target):
			state.collapse.movers.erase(key)
			var up := float(m.target) > current
			_event(state, src, int(key.get_slice(":", 0)), (4 if up else 5) + (2 if key.get_slice(":", 1) == "ceiling" else 0))
	if int(state.amber.state) == 5:
		state.amber.timer = maxf(float(state.amber.timer) - delta, 0.0)
		if state.amber.timer == 0.0:
			state.amber = {"state":2,"timer":0.0}
			changed = true
	return changed
