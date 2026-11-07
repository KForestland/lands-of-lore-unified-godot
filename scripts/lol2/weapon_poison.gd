extends RefCounted
## Weapon poison coats (AI_COMMS POISON_SILENT_KILL_20261027.md; docs/poison-paint.md). The original keeps two coat
## counters on the interface object 0x23819: +0x42A (0x23C43, Poison Paint, handler 10 mode 0x0C adds one through
## 0x82DCC) and +0x42B (0x23C44, Death sac through 0x82E10). The player's armed melee strike (0x88FD0) spends the
## death-sac counter first and ORs 0x40 into the hit's flags word, else the paint counter with 0x20, one coat per
## strike. A use is refused once the two counters sum to 9 (0x968B6). The port keeps the packet in
## `quest_state.weapon_poison`; older saves load it as empty.
const PAINT := "jungle:thieves_den:Pois_paint"
const MAX_COATS := 9
const FLAG_PAINT := 0x20
const FLAG_SAC := 0x40
const RING_TINT := Color(0.55,1.0,0.55)

static func initial() -> Dictionary:
	return {"version":1,"paint":0,"sac":0}
static func normalize(state: Dictionary) -> Dictionary:
	if not state.has("version"): state.version = 1
	for key in ["paint","sac"]:
		if not state.has(key): state[key] = 0
	return state
static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(value) and value >= low and value <= high
static func validate(state: Variant) -> String:
	if not state is Dictionary or not _integer(state.get("version",1),1,1): return "Invalid weapon poison packet."
	for key in ["paint","sac"]:
		if not _integer(state.get(key,0),0,MAX_COATS): return "Invalid weapon poison coats."
	if int(state.get("paint",0))+int(state.get("sac",0)) > MAX_COATS: return "Invalid weapon poison coats."
	return ""
static func coats(state: Dictionary) -> int:
	normalize(state)
	return int(state.paint)+int(state.sac)
## Handler 10 mode 0x0C (0x968A5): refused at 9 coats (the item is kept), else one paint coat.
static func apply_paint(state: Dictionary) -> bool:
	normalize(state)
	if coats(state) >= MAX_COATS: return false
	state.paint = int(state.paint)+1
	return true
## The strike's coat (0x88FD0..0x89113): the death-sac counter first (0x40), else the paint counter (0x20), else 0.
static func strike_flag(state: Dictionary) -> int:
	normalize(state)
	if int(state.sac) > 0:
		state.sac = int(state.sac)-1
		return FLAG_SAC
	if int(state.paint) > 0:
		state.paint = int(state.paint)-1
		return FLAG_PAINT
	return 0

## ---- host access ---------------------------------------------------------------------------------------------------
## The packet lives with the Act 1 quests; hosts without a quest bank (none in Act 1) have no coats.
static func bank(host: Object) -> Dictionary:
	if host == null or host.get("quest_state") == null or not host.quest_state is Dictionary: return {}
	if not host.quest_state.has("weapon_poison"): host.quest_state.weapon_poison = initial()
	return normalize(host.quest_state.weapon_poison)
static func host_coats(host: Object) -> int:
	var state := bank(host)
	return coats(state) if not state.is_empty() else 0
## Spends a coat for a landed armed strike on `host`; returns the hit flag (0x20 / 0x40 / 0).
static func spend(host: Object) -> int:
	var state := bank(host)
	if state.is_empty() or str(host.get("equipped_item")).is_empty(): return 0
	var flag := strike_flag(state)
	if flag != 0 and host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.has_method("refresh_equipment"): host.interface_hud.refresh_equipment()
	return flag
## The inventory's Use on Poison Paint (the port's stand-in for the weapon-circle drop, docs/DEVIATIONS.md).
static func use(host: Object, id: String) -> bool:
	if id != PAINT: return false
	var state := bank(host)
	if state.is_empty() or not id in host.carried_collected or not apply_paint(state): return false
	host.carried_collected.erase(id)
	if host.get("hand_item") == id: host.hand_item = ""
	if host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.has_method("refresh_equipment"): host.interface_hud.refresh_equipment()
	return true
