extends RefCounted
## Portable validation of the saved Bacatta57 packet before any scene/save mutation.
const State=preload("res://scripts/lol2/jungle_bacatta57_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const POPULATION:="res://scripts/lol2/jungle_bacatta57_population_source.json"
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=4 or not (packet.get("version") is int or packet.get("version") is float) or packet.version!=1: return "Invalid Bacatta57 packet."
	var src:=State.source()
	var error:=State.validate(packet.get("branch"),src)
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("body"),Generic.source(POPULATION))
	if not error.is_empty(): return error
	var regions: Array=src.regions.map(func(r): return int(r.region))
	if not packet.get("inside") is Array or packet.inside.size()>regions.size(): return "Invalid Bacatta57 region history."
	for r in packet.inside:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r)!=floorf(float(r)) or int(r) not in regions or packet.inside.count(r)!=1: return "Invalid Bacatta57 region history."
	if bool(packet.body.actors["57"].present)!=bool(packet.branch.actor.present): return "Bacatta57 body disagrees with the branch."
	return ""
