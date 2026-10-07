extends RefCounted
## Portable validation of the saved actor62 packet before any scene/save mutation.
const State=preload("res://scripts/lol2/jungle_actor62_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const POPULATION="res://scripts/lol2/jungle_actor62_population_source.json"
const MAX_RECEIPTS:=32
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=5 or packet.get("version")!=1: return "Invalid actor62 packet."
	if not FileAccess.file_exists(State.SOURCE) or not FileAccess.file_exists(POPULATION): return "actor62 source missing (run tools/prepare_jungle_actor62.py)."
	var src:=State.source()
	var error:=State.validate(packet.get("state"),src)
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("body"),Generic.source(POPULATION))
	if not error.is_empty(): return error
	if not packet.get("inside") is Array or not packet.get("receipts") is Array or packet.receipts.size()>MAX_RECEIPTS: return "Invalid actor62 packet."
	var regions: Array=src.regions.map(func(r):return int(r.region))
	var seen: Array=[]
	for r in packet.inside:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r)!=floorf(float(r)) or int(r) not in regions or int(r) in seen: return "Invalid actor62 region history."
		seen.append(int(r))
	var receipt_seen: Array=[]
	for r in packet.receipts:
		if not r is String or r.is_empty() or r.length()>64 or r.length()%2!=0 or not r.is_valid_hex_number() or r in receipt_seen: return "Invalid actor62 receipt."
		receipt_seen.append(r)
	var body: Dictionary=packet.body.actors["62"]
	if bool(body.present)!=bool(packet.state.present): return "actor62 body disagrees with the source state."
	return ""
