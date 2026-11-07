extends RefCounted
## Portable validation of the saved pre-exit conversation packet before any scene/save mutation.
const State=preload("res://scripts/lol2/jungle_exit_woman_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const POPULATION:="res://scripts/lol2/jungle_exit_woman_population_source.json"
const REGIONS:=[4387,4407,1902,1903,1907]
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=6 or packet.get("version")!=1: return "Invalid exit conversation packet."
	var src:=State.source()
	var error:=State.validate(packet.get("conversation"),src)
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("body"),Generic.source(POPULATION))
	if not error.is_empty(): return error
	if not packet.get("inside") is Array or not packet.get("sighted") is bool or not packet.get("exit_applied") is bool: return "Invalid exit conversation packet."
	var seen: Array=[]
	for r in packet.inside:
		if not (r is int or r is float) or not is_finite(float(r)) or int(r) not in REGIONS or float(r)!=floorf(float(r)) or int(r) in seen: return "Invalid exit conversation region history."
		seen.append(int(r))
	for id in src.actors:
		if bool(packet.body.actors[id].present)!=bool(packet.conversation.actors[id].present): return "Exit conversation body disagrees with the source state."
	if packet.exit_applied and (packet.conversation.prop.present or int(packet.conversation.local1)!=5): return "Exit spawn latch disagrees with prop554."
	return ""
