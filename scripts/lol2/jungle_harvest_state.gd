extends RefCounted
## Renewable Jungle Aloe plants (props254-260/311), Ironwood sap trees (props261-267/310) and the Aloe barrel prop1464
## (scripts/lol2/jungle_harvest_source.json). Owner states and kind2 timers follow the source records:
##  plant: state 0..3 (= selector; 3 bare). Harvest at s<3 enables timers 0..s, state+1, one "107-Aloe".
##         Timer j (900 s, periodic) offered at state j+1 stops itself and steps state back to j.
##  tree:  state 0 closed / 1..3 sap ready / 4 dry; selector = tapped while state>0. A matching hit at state0 opens
##         (state1). Harvest at 1..3 enables the timer, state+1, one "109-Ironwod sap". The timer (1080 s, periodic) steps
##         state-1 while state>0; at state0 the event3 group (selector0, stop timer) applies at once (adapter).
##  barrel: state 0..2 harvestable ("107-Aloe", no regrowth), 3 empty, 4 broken by a hit (selector1).
## Native timer rules (B47B4/B8BA0): enabling keeps the counter, stopping keeps it, expiry reloads it with carry.
## Invariants: a plant's timer j runs exactly when j < state; a tree's timer runs at state>=2, never at state0.
const Items = preload("res://scripts/lol2/jungle_harvest_items.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const PLANTS := ["254","255","256","257","258","259","260","311"]
const TREES := ["261","262","263","264","265","266","267","310"]
const BARREL := "1464"
const PLANT_PERIOD := 900.0
const TREE_PERIOD := 1080.0
const TREE_MASK0 := 0x010E
const TREE_MASK2 := 0x0004
const TREE_THRESHOLD := 3
const TREE_DURABILITY := 4

static func initial() -> Dictionary:
	var plants := {}; var trees := {}
	for id in PLANTS: plants[id] = {"state":0,"timers":[{"on":false,"left":PLANT_PERIOD},{"on":false,"left":PLANT_PERIOD},{"on":false,"left":PLANT_PERIOD}]}
	for id in TREES: trees[id] = {"state":0,"timer":{"on":false,"left":TREE_PERIOD}}
	return {"version":1,"plants":plants,"trees":trees,"barrel":{"state":0}}

static func _int_in(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) == floorf(float(v)) and v >= lo and v <= hi
static func _timer_error(t: Variant, period: float) -> String:
	if not t is Dictionary or t.size() != 2 or not t.get("on") is bool: return "Invalid harvest timer."
	var left = t.get("left")
	if not (left is int or left is float) or not is_finite(float(left)) or left <= 0 or left > period: return "Invalid harvest timer."
	return ""

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 4 or value.get("version") != 1: return "Invalid Jungle harvest state."
	if not value.get("plants") is Dictionary or value.plants.size() != PLANTS.size() or not value.get("trees") is Dictionary or value.trees.size() != TREES.size(): return "Invalid Jungle harvest state."
	for id in PLANTS:
		var p = value.plants.get(id)
		if not p is Dictionary or p.size() != 2 or not _int_in(p.get("state"), 0, 3) or not p.get("timers") is Array or p.timers.size() != 3: return "Invalid Aloe plant."
		for j in 3:
			var error := _timer_error(p.timers[j], PLANT_PERIOD)
			if not error.is_empty(): return error
			if p.timers[j].on != (j < int(p.state)): return "Aloe plant timers disagree with its state."
	for id in TREES:
		var t = value.trees.get(id)
		if not t is Dictionary or t.size() != 2 or not _int_in(t.get("state"), 0, 4): return "Invalid sap tree."
		var error := _timer_error(t.get("timer"), TREE_PERIOD)
		if not error.is_empty(): return error
		if (int(t.state) == 0 and t.timer.on) or (int(t.state) >= 2 and not t.timer.on): return "Sap tree timer disagrees with its state."
	var b = value.get("barrel")
	if not b is Dictionary or b.size() != 1 or not _int_in(b.get("state"), 0, 4): return "Invalid Aloe barrel."
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	var out := initial()
	for id in PLANTS:
		out.plants[id].state = int(value.plants[id].state)
		for j in 3: out.plants[id].timers[j] = {"on":bool(value.plants[id].timers[j].on),"left":float(value.plants[id].timers[j].left)}
	for id in TREES:
		out.trees[id] = {"state":int(value.trees[id].state),"timer":{"on":bool(value.trees[id].timer.on),"left":float(value.trees[id].timer.left)}}
	out.barrel.state = int(value.barrel.state)
	return out

## Displayed source selector (plant = state; tree tapped while open; barrel broken at state4).
static func selector(state: Dictionary, kind: String, id: String) -> int:
	if kind == "plant": return int(state.plants[id].state)
	if kind == "tree": return 1 if int(state.trees[id].state) > 0 else 0
	return 1 if int(state.barrel.state) == 4 else 0

static func harvestable(state: Dictionary, kind: String, id: String) -> bool:
	if kind == "plant": return int(state.plants[id].state) < 3
	if kind == "tree": return int(state.trees[id].state) in [1,2,3]
	return int(state.barrel.state) < 3

## Empty-hand use (kind4 mode0). inventory = {collected, hand, spent}. Atomic: returns the granted pool id, or "" with
## no change when the source has no record for the state, the hand is busy, the pool is exhausted or carrying is full.
static func harvest(state: Dictionary, kind: String, id: String, inventory: Dictionary) -> String:
	if inventory.hand != "" or not harvestable(state, kind, id): return ""
	if inventory.collected.size() >= Catalog.MAX_CARRIED: return ""
	var item := Items.next_free("sap" if kind == "tree" else "aloe", inventory.collected)
	if item.is_empty(): return ""
	if kind == "plant":
		var p: Dictionary = state.plants[id]
		for j in int(p.state) + 1: p.timers[j].on = true
		p.state = int(p.state) + 1
	elif kind == "tree":
		var t: Dictionary = state.trees[id]
		t.timer.on = true
		t.state = int(t.state) + 1
	else:
		state.barrel.state = int(state.barrel.state) + 1
	inventory.spent.erase(item)
	inventory.collected.append(item)
	inventory.hand = item
	return item

## Hit (kind9). context = {mask0, mask2, damage}; remaining durability is derived from the placement durability.
static func hit(state: Dictionary, kind: String, id: String, context: Dictionary) -> bool:
	var damage := int(context.get("damage", 0))
	if kind == "tree":
		var t: Dictionary = state.trees[id]
		if int(t.state) != 0 or not (int(context.mask0) & TREE_MASK0) or not (int(context.mask2) & TREE_MASK2): return false
		if maxi(TREE_DURABILITY - damage, 0) > TREE_THRESHOLD: return false
		t.state = 1
		return true
	if kind == "barrel":
		if int(state.barrel.state) == 4 or damage < 1: return false
		state.barrel.state = 4
		return true
	return false

## Runs every enabled timer for `delta` seconds of active world time in expiry order. Returns true on a state change.
static func advance(state: Dictionary, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0: return false
	var changed := false
	for id in PLANTS:
		var p: Dictionary = state.plants[id]
		var left := delta
		while true:
			var next := -1
			for j in 3:
				if p.timers[j].on and (next < 0 or float(p.timers[j].left) < float(p.timers[next].left)): next = j
			if next < 0: break
			# Drain all simultaneous expiries, even when this update used its entire delta.
			if left <= 0 and float(p.timers[next].left) > 0: break
			var step: float = minf(left, float(p.timers[next].left))
			for j in 3:
				if p.timers[j].on: p.timers[j].left = float(p.timers[j].left) - step
			left -= step
			if float(p.timers[next].left) > 0.000001: break
			p.timers[next].left = PLANT_PERIOD
			if int(p.state) == next + 1:
				p.timers[next].on = false
				p.state = next
				changed = true
	for id in TREES:
		var t: Dictionary = state.trees[id]
		var left := delta
		while t.timer.on and left > 0:
			if left < float(t.timer.left): t.timer.left = float(t.timer.left) - left; break
			left -= float(t.timer.left)
			t.timer.left = TREE_PERIOD
			if int(t.state) > 0:
				t.state = int(t.state) - 1
				changed = true
			if int(t.state) == 0: t.timer.on = false
	return changed
