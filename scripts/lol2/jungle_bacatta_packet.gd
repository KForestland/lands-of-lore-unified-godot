extends RefCounted
## Portable validation before any scene/save mutation.
const State=preload("res://scripts/lol2/jungle_bacatta_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=5 or packet.get("version")!=1: return "Invalid Bacatta packet."
	var error:=State.validate(packet.get("branch"),State.source(),State.timing())
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("body"),Generic.source("res://scripts/lol2/jungle_bacatta_population_source.json"))
	if not error.is_empty(): return error
	if not packet.get("inside") is Array or not packet.get("sighted") is bool: return "Invalid Bacatta packet."
	if packet.inside.size()>1: return "Duplicate Bacatta region history."
	for r in packet.inside:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r)!=1921.0: return "Invalid Bacatta region history."
	var b: Dictionary=packet.branch.bacatta
	if bool(packet.body.actors["61"].present)!=bool(b.present): return "Bacatta body disagrees with the branch."
	return ""

