extends RefCounted
## Portable validation of the saved village alarm packet before any scene/save mutation.
const State=preload("res://scripts/lol2/jungle_village_alarm_state.gd")
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=3 or not (packet.get("version") is int or packet.get("version") is float) or packet.version!=1: return "Invalid village alarm packet."
	var src:=State.source()
	var error:=State.validate(packet.get("state"),src)
	if not error.is_empty(): return error
	if not packet.get("inside") is bool: return "Invalid village alarm region history."
	return ""
