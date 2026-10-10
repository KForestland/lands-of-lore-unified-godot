extends RefCounted
## "26-Net of Exile" on-hit adapter (docs/net-exile-onhit.md). Source handler104 (0x9B718): on a landed hit
## (event17) against a creature (class2) it binds a family-4 timed effect to the target (10E2F8, lifetime
## +0x6E=0xA0000, read as 10s). Modern adapter: a landed hit with the Net equipped holds the living creature
## for SECONDS (no movement or attack, a started attack is cancelled); a repeat hit refreshes, never stacks.
## Holds are transient combat state ({actor id: seconds left} on the population): save/load, restore and
## area change release them, as checkpoint recovery drops unfinished attacks.
const ITEM := "hive:prop214:Net_of_Exile"
const SECONDS := 10.0

static func equipped(item: String) -> bool:
	return item == ITEM

## After a landed hit: hold a still-living target when the Net is the equipped weapon.
static func apply(holds: Dictionary, id: String, item: String, alive: bool) -> bool:
	if not equipped(item) or not alive: return false
	holds[id] = SECONDS
	return true

static func held(holds: Dictionary, id: String) -> bool:
	return float(holds.get(id, 0.0)) > 0.0

## World time only (callers skip this while the world is paused).
static func tick(holds: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	for id in holds.keys():
		holds[id] = maxf(0.0, float(holds[id]) - delta)
		if holds[id] <= 0.0: holds.erase(id)

static func feedback(name: String) -> String:
	return "The Net of Exile entangles the %s." % name.to_lower()

## Host feedback line: save_feedback (Jungle/Cave hosts) or the Hive interface HUD notice.
static func notify(host: Node, text: String) -> void:
	if host.has_method("save_feedback"): host.save_feedback(text)
	elif is_instance_valid(host.get("interface_hud")):
		host.interface_hud.hint.text = text
		host.interface_hud.save_notice_remaining = 2.5
