extends RefCounted
## Cave waterfall room CFALL (room 32, CFALL_.WOM) as ordered host effects, one function per native callback, and its
## saved state. Source contract: scripts/lol2/cave_cfall_source.json (tools/prepare_cave_cfall_room.py); report
## AI_COMMS/act1_completion_20261017/CAVE_CFALL_BUILD_20261028.md. Inputs come from the caller; nothing is applied here.
## Saved by the Cave host as "cave_cfall": host flags 5 (first-visit quip said) and 6 (drunk from the pool; written,
## never read by any room or host site).
const SOURCE := "res://scripts/lol2/cave_cfall_source.json"
const HEAL_MAXIMUM := 30 # Port maximum health, as the Morgan orb heal (the same native D6A08 routine).

static func source() -> Dictionary:
	if not FileAccess.file_exists(SOURCE): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return data if data is Dictionary and int(data.get("room", -1)) == 32 else {}

static func initial() -> Dictionary: return {"version":1,"flags":{"5":0,"6":0}}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or value.get("version") != 1 or not value.get("flags") is Dictionary: return "Invalid CFALL state."
	if value.flags.size() != 2: return "Invalid CFALL flags."
	for key in ["5","6"]:
		var v = value.flags.get(key)
		if not (v is int or v is float) or not (v == 0 or v == 1): return "Invalid CFALL flags."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	return {"version":1,"flags":{"5":int(value.flags["5"]),"6":int(value.flags["6"])}}

static func _cue(line: int) -> Array: return ["movie",2,line,24]
## Callback 1 (0x47C).
static func setup_effects(src: Dictionary) -> Array:
	var effects: Array = []
	for h in src.hotspots: effects.append(["hotspot"]+h)
	return effects
## Callback 9 (0x541): the ambient loop, then the first-visit quip once (flag 5).
static func first_update(state: Dictionary, src: Dictionary) -> Array:
	var effects: Array = [["ambient_start",int(src.ambient[0]),int(src.ambient[1])]]
	if int(state.flags["5"]) == 0: effects.append_array([["set_flag",5],_cue(26)])
	return effects
## Callback 4 (0x4F5): either pool hotspot drinks: D6A08(player, 5), two quips, flag 6. Every click; no latch.
static func click(hotspot: int, src: Dictionary) -> Array:
	if hotspot != 0 and hotspot != 1: return []
	return [["heal",int(src.heal)],_cue(55),_cue(20),["set_flag",6]]
## Callback 8 (0x538): exit_room; the entry region's op18 then places the player (flags 0x0885).
static func leave(src: Dictionary, region: int) -> Array:
	for row in src.regions:
		if int(row.region) == region: return [["exit_room"],["place",int(row.place.x),int(row.place.y),float(row.place.yaw)]]
	return [["exit_room"]]
## Native hotspot test on the 640x400 room canvas (inclusive rects, lowest id first).
static func hotspot_at(src: Dictionary, point: Vector2i) -> int:
	for h in src.hotspots:
		if point.x >= int(h[1]) and point.y >= int(h[2]) and point.x <= int(h[3]) and point.y <= int(h[4]): return int(h[0])
	return -1
## Region event 2 (grounded entry): the entry region whose polygon holds the native point and whose floor the foot is on.
static func region_at(src: Dictionary, point: Vector2, foot: float) -> int:
	for row in src.regions:
		if foot < float(row.floor_min) - 2.0 or foot > float(row.floor_max) + 4.0: continue
		var polygon := PackedVector2Array()
		for v in row.polygon: polygon.append(Vector2(v[0], v[1]))
		if Geometry2D.is_point_in_polygon(point, polygon): return int(row.region)
	return -1
## D6A08(player, n), n >= 0: nothing when dead or player+0x229 bit 1; else health + n up to the maximum.
static func heal(current: int, amount: int) -> int:
	return preload("res://scripts/lol2/morgan_orb_blessing.gd").heal(current, HEAL_MAXIMUM, 0, amount)
