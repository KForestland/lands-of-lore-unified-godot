extends RefCounted
## Portable validation of the saved Kelsrick64 packet before any scene/save mutation.
const State=preload("res://scripts/lol2/jungle_kelsrick_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const POPULATION="res://scripts/lol2/jungle_kelsrick_population_source.json"
const MAX_RECEIPTS:=64
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=6 or packet.get("version")!=1: return "Invalid Kelsrick packet."
	if not FileAccess.file_exists(State.MEDIA): return "Kelsrick media missing (run tools/prepare_jungle_kelsrick.py)."
	var src:=State.source()
	var error:=State.validate(packet.get("state"),src,State.media())
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("body"),Generic.source(POPULATION))
	if not error.is_empty(): return error
	if not packet.get("hold") is bool or not packet.get("inside") is Array or not packet.get("receipts") is Array: return "Invalid Kelsrick packet."
	if bool(packet.hold) and int(packet.state.health)==0: return "Dead Kelsrick cannot hold the player."
	var regions: Array=src.regions.map(func(r):return int(r.region))
	var seen: Array=[]
	for r in packet.inside:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r)!=floorf(float(r)) or int(r) not in regions or int(r) in seen: return "Invalid Kelsrick region history."
		seen.append(int(r))
	if packet.receipts.size()>MAX_RECEIPTS: return "Invalid Kelsrick receipts."
	var receipt_seen: Array=[]
	for r in packet.receipts:
		if not r is String or r.is_empty() or r.length()>64 or r.length()%2!=0 or not r.is_valid_hex_number() or r in receipt_seen: return "Invalid Kelsrick receipt."
		receipt_seen.append(r)
	if bool(packet.body.actors["64"].present)!=bool(packet.state.present): return "Kelsrick body disagrees with the source state."
	return ""
