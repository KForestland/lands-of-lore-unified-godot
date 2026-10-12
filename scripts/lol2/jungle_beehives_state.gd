extends RefCounted
## Jungle beehives props251-253 (scripts/lol2/jungle_beehives_source.json). Per hive: fullness 0 full / 1 half /
## 2 empty (source owner state and selector) and the running kind2 timer. Each empty-hand harvest at fullness 0/1 grants
## one "71-Wax" and advances fullness; the timer steps 2 -> 1 -> 0 (regrowth). REGROW is a modern adapter for the source
## 244..250 timer units (flag 0x10; unit rate unproved).
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Wax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
const HIVES := ["251","252","253"]
const REGROW := 247.0
static func initial() -> Dictionary:
	var hives := {}
	for id in HIVES: hives[id] = {"fullness":0,"timer":0.0}
	return {"version":1,"hives":hives}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or value.get("version") != 1 or not value.get("hives") is Dictionary or value.hives.size() != HIVES.size(): return "Invalid Jungle beehive state."
	for id in HIVES:
		var hive = value.hives.get(id)
		if not hive is Dictionary or hive.size() != 2: return "Invalid Jungle beehive."
		var fullness = hive.get("fullness"); var timer = hive.get("timer")
		if not (fullness is int or fullness is float) or not (fullness == 0 or fullness == 1 or fullness == 2): return "Invalid beehive fullness."
		if not (timer is int or timer is float) or not is_finite(float(timer)) or timer < 0 or timer > REGROW: return "Invalid beehive timer."
		if int(fullness) == 0 and timer != 0: return "Full beehive cannot be regrowing."
		if int(fullness) > 0 and timer <= 0: return "Harvested beehive has no regrowth timer."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	var out := initial()
	for id in HIVES: out.hives[id] = {"fullness":int(value.hives[id].fullness),"timer":float(value.hives[id].timer)}
	return out
## Empty-hand harvest. Returns the granted pool id, or "" when refused (empty hive, busy hand, pool exhausted).
static func harvest(state: Dictionary, hive: String, inventory: Dictionary) -> String:
	if not state.hives.has(hive) or inventory.hand != "" or inventory.collected.size() >= Catalog.MAX_CARRIED: return ""
	var h: Dictionary = state.hives[hive]
	if int(h.fullness) >= 2: return ""
	var id := Wax.next_free(inventory.collected)
	if id.is_empty(): return ""
	inventory.collected.append(id)
	inventory.hand = id
	if int(h.fullness) == 0: h.timer = REGROW
	h.fullness = int(h.fullness) + 1
	return id
## Regrowth: each expiry restores one stage (2 -> 1 restarts the timer; 1 -> 0 stops it).
static func advance(state: Dictionary, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0: return false
	var changed := false
	for id in HIVES:
		var h: Dictionary = state.hives[id]
		var left := delta
		while int(h.fullness) > 0 and left > 0:
			if left < float(h.timer): h.timer = float(h.timer) - left; left = 0; break
			left -= float(h.timer); h.fullness = int(h.fullness) - 1; changed = true
			h.timer = REGROW if int(h.fullness) > 0 else 0.0
	return changed
