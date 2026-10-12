extends RefCounted
const State=preload("res://scripts/lol2/jungle_drunk_state.gd")
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=3 or not State.integer(packet.get("version"),1,1): return "Invalid drunk packet."
	var error:=State.validate(packet.get("state"),State.source())
	if not error.is_empty(): return error
	if not packet.get("inside") is Array: return "Invalid drunk region history."
	var ids: Array=State.source().regions.map(func(r):return int(r.id))
	for id in packet.inside:
		if not State.integer(id,0,65535) or int(id) not in ids or packet.inside.count(id)!=1: return "Invalid drunk region."
	return ""
