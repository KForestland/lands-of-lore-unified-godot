extends RefCounted
## Original world-item rows of the Museum (L3_DH), the Dark Halls (L7_DH) and the Savage Jungle (L8_SJ) that the port did not
## reference before 2026-10-31 (ITEM_CENSUS_AND_PLAN_20261025.md section 2 list, re-counted from AI_COMMS item_census.json;
## the Jungle and Hive entries of that list were already hosted). Admitted here: live rows (flags 0x0002 exactly, dormant bit
## clear) whose region the player reaches from the level start in the native region graph without crossing a bit0 region
## (tools/world_item_reachability.py, strict pass) and whose point the Godot probe (tools/probe_world_items.gd) found on a
## floor with a clear line of sight. Position is the native (x, region floor, -y) like the Hive rows (hive_world_items_state.gd);
## the controller settles the sprite base onto the physics floor within 80 units of that height (presentation).
## Left out, with the reason: L8 rows 25 (58-Br dead, region 3782) and 26 (117-Amaranth sr, region 3781) lie in regions no
## walk from the start reaches (strict and permissive); L8 rows 29/30 (R-Mindcl, R-Warcl) carry flags 0x8002 and bit 0x8000
## is untraced; the Cave rows (0-3, 5, 17-20) and Hive rows 4/10 carry 0x0402 and bit 0x0400 is untraced (G34/G36).
## Collected rows are pickup history, separate from the carried copies; native pickup admission and item handlers are not
## replayed (item_handlers.gd routes any use).
const AREAS := {
	"museum": {"key": "museum_world_items", "prefix": "museum:item", "origin": "museum", "level": "L3_DH",
		"rows": [0], "definitions": [167], "identities": [2148793954], "names": ["Cocos Cap"], "regions": [706],
		"positions": [Vector3(1377, 10, -227)]},
	"darkhalls": {"key": "dark_halls_world_items", "prefix": "darkhalls:item", "origin": "jungle", "level": "L7_DH",
		"rows": [4, 5, 28], "definitions": [141, 12, 38], "identities": [1521007029, 4033986741, 515254933],
		"names": ["139-SS6", "13-Gaunt strike", "39-Orc shield"], "regions": [1575, 1576, 1363],
		"positions": [Vector3(-1328, 750, -950), Vector3(-1125, 750, -969), Vector3(-1857, 310, -2072)]},
	"darkerjungle": {"key": "darker_jungle_world_items", "prefix": "darkerjungle:item", "origin": "jungle", "level": "L8_SJ",
		"rows": [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 28],
		"definitions": [114, 114, 114, 114, 114, 114, 114, 114, 114, 114, 114, 114, 164],
		"identities": [4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 4126891770, 1677845645],
		"names": ["112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "112-Lamplt eggs", "R-Manafoil"],
		"regions": [2668, 1235, 2513, 1383, 2756, 871, 871, 763, 781, 1149, 515, 1758, 422],
		"positions": [Vector3(-276, 0, 2395), Vector3(-199, 0, 1659), Vector3(-611, 0, 668), Vector3(2598, 0, 736), Vector3(1707, 0, -48), Vector3(647, 0, -1638),
			Vector3(669, 0, -1654), Vector3(170, -5, -918), Vector3(-561, 0, -584), Vector3(584, -5, 726), Vector3(-2374, 0, 137), Vector3(4777, 0, -1718), Vector3(1686, -494, -929)]},
}
const Definitions := preload("res://scripts/lol2/item_definitions.gd")

static func areas() -> Array: return AREAS.keys()
static func key(area: String) -> String: return str(AREAS[area].key)
static func rows(area: String) -> Array: return AREAS[area].rows
## "museum:item0:Cocos_Cap": prefix, row and the definition's label with underscores (the Jungle rows' shape).
static func id_of(area: String, row: int) -> String:
	var i: int = AREAS[area].rows.find(row)
	if i < 0: return ""
	return "%s%d:%s" % [AREAS[area].prefix, row, Definitions.label(AREAS[area].definitions[i]).replace(" ", "_")]
static func ids(area: String) -> Array:
	var out := []
	for row in AREAS[area].rows: out.append(id_of(area, row))
	return out
static func all_ids() -> Array:
	var out := []
	for area in AREAS: out += ids(area)
	return out
static func area_of(id: Variant) -> String:
	if not id is String: return ""
	for area in AREAS:
		if id in ids(area): return area
	return ""
static func valid(id: Variant) -> bool: return not area_of(id).is_empty()
static func row_of(id: String) -> int:
	var area := area_of(id)
	if area.is_empty(): return -1
	return AREAS[area].rows[ids(area).find(id)]
static func definition(id: String) -> int:
	var area := area_of(id)
	return AREAS[area].definitions[ids(area).find(id)] if not area.is_empty() else -1
static func source_name(id: String) -> String:
	var area := area_of(id)
	return str(AREAS[area].names[ids(area).find(id)]) if not area.is_empty() else ""
static func origin(id: String) -> String:
	var area := area_of(id)
	return str(AREAS[area].origin) if not area.is_empty() else ""

static func initial() -> Dictionary: return {"version": 1, "collected": []}
## Saved pickup history of one area: {"version": 1, "collected": [rows]} with each row admitted once.
static func validate(saved: Variant, area: String) -> String:
	if not saved is Dictionary or saved.size() != 2 or saved.get("version") != 1 or not saved.get("collected") is Array: return "Invalid %s world-item history." % area
	var seen: Array = []
	for r in saved.collected:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r) != floorf(float(r)) or int(r) not in AREAS[area].rows or int(r) in seen: return "Invalid %s world-item row." % area
		seen.append(int(r))
	return ""
## Rows as ints (JSON loads them as floats); [] for an invalid or absent history.
static func rows_of(saved: Variant, area: String) -> Array:
	return saved.collected.map(func(r): return int(r)) if validate(saved, area).is_empty() else []
