extends RefCounted
## Load rule (lead 2026-11-14, approved after the L19 cab ride-back: DEVIATIONS row). A load PLACES the body; it does not
## walk into its region. The original's save holds its world state whole and its loader sets the player's region
## directly; the port's area save does not hold everything (listed kind-2 timers, effects, room/ambience requests), and the
## next physics tick used to count the loaded region as entered and re-run its entry group: a lever press (L19 cab turned
## back), a pose that moves Luther, a movie, a mover started twice.
## On every Act 2/3 map a load sets the progression's region without the entry event, then RE-ARMS the loaded region's
## entry group with only the commands that are safe to run again. This table is the one place that decides; the census
## test (tests/load_region_rule_test.gd) fails when an entry group in any staged level holds an opcode on neither list,
## so a new opcode is a decision, not a silent default.
##
## Repeat-safe (re-armed on load): what the save does not keep and the region needs while Luther stands in it.
## SAVED STATE WINS (lead 2026-11-14 after Grok R118 (a): L4 record 3805 bit 0 put back after control 82 cleared it):
## native_script_host.rearm_region dry-runs each command and skips it when the loaded save already holds any target it
## writes (record fields and bits, floor targets, locals, [0x26E58] cells, record bytes); only unsaved targets are re-armed.
const REARM := {
	12: "room/ambience request (archive stem; an idempotent request)",
	14: "kind-2 timer list/unlist (hazard and effect timers of the zone)",
	15: "effect request (the zone's visual/hazard effect)",
	196: "absolute floor target (word +4 and rate)",
	197: "absolute region-record bit set/clear",
	198: "absolute [0x26E54] local store",
}
## Never on load: one-shot or cumulative, or not yet decided (199/204: absolute writes outside the approved list).
const NEVER := {
	1: "mover travel (starts a door/mover)", 2: "object arms (scene/level change, flags, counters on 0x22574)",
	3: "item grant", 5: "object store with follow-ups", 6: "object record start/move/restart", 7: "object records bits",
	8: "player record set/release", 9: "enqueue (lever presses, callbacks)", 13: "actor slots (spawn, modes)",
	16: "mover/prop mode", 18: "player pose (moves Luther)", 19: "effect record", 20: "object timer/animation",
	21: "movie", 24: "not decoded", 199: "[0x26E58] local store (absolute; outside the approved list, lead to decide)",
	204: "region record word (absolute; outside the approved list, lead to decide)", 206: "not decoded",
	207: "counter add", 208: "cells raise/clear", 209: "not decoded", 210: "cells/word store",
}
const AREAS := ["L4_HJ", "L8_SJ", "L9_DR", "L10_DC", "L12_CM", "L13_RC", "L14_HT", "L16_CA", "L17_HC", "L19_BC", "L20_BB"]

## After a host applied a save: set the region where the save put the body (no entry), then re-arm.
static func apply(host: Node) -> Array:
	var progression: Variant = host.get("progression")
	if not is_instance_valid(progression) or not progression.has_method("region_at"): return []
	var area := str(progression.get("area_id"))
	if not area in AREAS: return []
	var player: Variant = host.get("player")
	if not player is Node3D: return []
	var shift: Vector3 = host.get("native_translation") if host.get("native_translation") is Vector3 else Vector3.ZERO
	var region: int = int(progression.region_at((player as Node3D).global_position - shift))
	progression.current_region = region
	if region < 0 or progression.get("native") == null: return []
	var results: Array = progression.native.call("rearm_region", region, REARM.keys())
	progression.load_rearm_log.append({"object": "region:%d" % region, "event": "load_rearm", "results": results})
	return results
