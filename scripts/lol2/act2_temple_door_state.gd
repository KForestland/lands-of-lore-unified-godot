extends RefCounted
## TMPLDOR_.WOM callbacks, static source contract in act2_temple_door_source.json.
## This models the door only; acquiring the dreamstone and playing room media are separate.
const ITEM := "134-Dreamstone"
static func initial() -> Dictionary:
	return {"open":false, "entered":false}
static func validate(state: Variant) -> String:
	if not state is Dictionary or state.size() != 2 or not state.get("open") is bool or not state.get("entered") is bool:
		return "Invalid temple door state."
	if state.entered and not state.open: return "Temple entered through closed door."
	return ""
## Original hotspot1 tests the held item's exact name (host+0x8C), not inventory ownership.
## Matching it toggles flag272; the original does not consume the dreamstone here.
static func offer(state: Dictionary, held_name: String) -> bool:
	if not validate(state).is_empty() or state.entered or held_name != ITEM: return false
	state.open = not state.open
	return true
## Original hotspot2 tests flag272 and writes named L8 local13 before leaving the room.
static func enter(state: Dictionary, native: RefCounted) -> bool:
	if not validate(state).is_empty() or not state.open or state.entered: return false
	native.call("set_local", 13, 1)
	state.entered = true
	return true
