extends RefCounted
## Portable validation of the saved Dawn63 packet before any scene/save mutation.
const State=preload("res://scripts/lol2/jungle_dawn_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const POPULATION="res://scripts/lol2/jungle_dawn_population_source.json"
const MAX_RECEIPTS:=64
const Projectiles=preload("res://scripts/lol2/dawn_projectile_store.gd")
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=6+int(packet.has("projectiles"))+int(packet.has("combat")) or packet.get("version")!=1: return "Invalid Dawn packet."
	if not FileAccess.file_exists(State.MEDIA) or not FileAccess.file_exists(POPULATION): return "Dawn media missing (run tools/prepare_jungle_dawn_media.py and prepare_jungle_dawn_population.py)."
	var combat_error:=preload("res://scripts/lol2/dawn_modern_combat.gd").validate(packet.get("combat",preload("res://scripts/lol2/dawn_modern_combat.gd").initial()))
	if not combat_error.is_empty():return combat_error
	var projectile_error:=Projectiles.validate(packet.get("projectiles",Projectiles.initial()))
	if not projectile_error.is_empty():return projectile_error
	for effect in packet.get("projectiles",Projectiles.initial()).effects:
		if int(effect.owner)!=63:return "Projectile belongs to another caster."
	var src:=State.source()
	var error:=State.validate(packet.get("state"),src,State.media())
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("body"),Generic.source(POPULATION))
	if not error.is_empty(): return error
	if not packet.get("hold") is bool or not packet.get("inside") is Array or not packet.get("receipts") is Array: return "Invalid Dawn packet."
	if bool(packet.hold) and (int(packet.state.health)==0 or not bool(packet.state.present)): return "Absent or dead Dawn cannot hold the player."
	var regions: Array=src.regions.map(func(r):return int(r.region))
	var seen: Array=[]
	for r in packet.inside:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r)!=floorf(float(r)) or int(r) not in regions or int(r) in seen: return "Invalid Dawn region history."
		seen.append(int(r))
	if packet.receipts.size()>MAX_RECEIPTS: return "Invalid Dawn receipts."
	var receipt_seen: Array=[]
	for r in packet.receipts:
		if not r is String or r.is_empty() or r.length()>64 or r.length()%2!=0 or not r.is_valid_hex_number() or r in receipt_seen: return "Invalid Dawn receipt."
		receipt_seen.append(r)
	if bool(packet.body.actors["63"].present)!=bool(packet.state.present): return "Dawn body disagrees with the source state."
	return ""
