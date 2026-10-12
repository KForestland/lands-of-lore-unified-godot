extends RefCounted
## Portable validation of the saved Hive Dawn20 packet before any scene/save mutation.
const State=preload("res://scripts/lol2/hive_dawn20_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const POPULATION="res://scripts/lol2/hive_dawn20_population_source.json"
const MAX_RECEIPTS:=64
const Projectiles=preload("res://scripts/lol2/dawn_projectile_store.gd")
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=5+int(packet.has("projectiles"))+int(packet.has("combat")) or packet.get("version")!=1: return "Invalid Hive Dawn packet."
	if not FileAccess.file_exists(State.MEDIA) or not FileAccess.file_exists(POPULATION): return "Hive Dawn media missing (run tools/prepare_hive_dawn20_media.py and prepare_hive_dawn20_population.py)."
	var combat_error:=preload("res://scripts/lol2/dawn_modern_combat.gd").validate(packet.get("combat",preload("res://scripts/lol2/dawn_modern_combat.gd").initial()))
	if not combat_error.is_empty():return combat_error
	var projectile_error:=Projectiles.validate(packet.get("projectiles",Projectiles.initial()))
	if not projectile_error.is_empty():return projectile_error
	for effect in packet.get("projectiles",Projectiles.initial()).effects:
		if int(effect.owner)!=20:return "Projectile belongs to another caster."
	var src:=State.source()
	var error:=State.validate(packet.get("state"),src,State.media())
	if not error.is_empty(): return error
	error=Generic.validate(packet.get("body"),Generic.source(POPULATION))
	if not error.is_empty(): return error
	if not packet.get("hold") is bool or not packet.get("receipts") is Array: return "Invalid Hive Dawn packet."
	if bool(packet.hold) and (int(packet.state.health)==0 or not bool(packet.state.present)): return "Absent or dead Dawn cannot hold the player."
	if packet.receipts.size()>MAX_RECEIPTS: return "Invalid Hive Dawn receipts."
	var receipt_seen: Array=[]
	for r in packet.receipts:
		if not r is String or r.is_empty() or r.length()>64 or r.length()%2!=0 or not r.is_valid_hex_number() or r in receipt_seen: return "Invalid Hive Dawn receipt."
		receipt_seen.append(r)
	if bool(packet.body.actors["20"].present)!=bool(packet.state.present): return "Hive Dawn body disagrees with the source state."
	return ""
