extends Node
## Explored atlas regions live on the host, not in quest_state.
## Saves write that field as its own top-level key beside quests.
## A new game starts empty. Visit and sight add region ids.
## An old save with this key missing marks the host area and every act2_creatures area full.
## A save that still keeps the key inside quests moves it out on load.
## A finished area collapses to full so the save stays a short flag. No renderer.
const KEY: String = "atlas_explored"
const CREATURE_AREAS: Array[String] = ["L8_SJ", "L9_DR", "L10_DC", "L12_CM", "L13_RC", "L14_HT", "L16_CA", "L17_HC", "L19_BC", "L20_BB"]
const REGION_LIMIT := 12000
var host: Node
var nav: Array = []
var last_stand := Vector3(INF, INF, INF)
var last_region := -1

static func initial() -> Dictionary:
	return {"version": 1, "areas": {}}

static func area_of(node: Node) -> String:
	var named: Variant = node.get("area_id")
	if named is String and named != "": return named
	var path := str(node.get("geometry_file"))
	if path.ends_with("darker_jungle/area.json"): return "L8_SJ"
	if path.ends_with("dark_halls/area.json"): return "L7_DH"
	if path.ends_with("hive.json"): return "L5_HC"
	if path.ends_with("jungle.json"): return "L4_HJ"
	return ""

static func area_name_ok(area: String) -> bool:
	if area.length() < 2 or area.length() > 16: return false
	for i in area.length():
		var code := area.unicode_at(i)
		var letter := code >= 65 and code <= 90
		var digit := code >= 48 and code <= 57
		if i == 0 and not letter: return false
		if not letter and not digit and code != 95: return false
	return true

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid atlas explored."
	if not saved is Dictionary or saved.size() != 2 or int(saved.get("version", 0)) != 1: return "Invalid atlas explored."
	if not saved.get("areas") is Dictionary: return "Invalid atlas explored."
	for area in saved.areas:
		if not area is String or not area_name_ok(area): return "Invalid atlas explored."
		var row: Variant = saved.areas[area]
		if not row is Dictionary or not row.get("full") is bool or not row.get("regions") is Array: return "Invalid atlas explored."
		if bool(row.full) and not row.regions.is_empty(): return "Invalid atlas explored."
		if row.regions.size() > REGION_LIMIT: return "Invalid atlas explored."
		var seen := {}
		for raw in row.regions:
			if not (raw is int or raw is float) or float(raw) != float(int(raw)): return "Invalid atlas explored."
			var id := int(raw)
			if id < 0 or id >= REGION_LIMIT or seen.has(id): return "Invalid atlas explored."
			seen[id] = true
	return ""

static func read_error(state: Variant) -> String:
	if not state is Dictionary: return ""
	if state.has(KEY):
		var top_error := validate(state.get(KEY), {})
		if not top_error.is_empty(): return top_error
	var quests: Variant = state.get("quests")
	if quests is Dictionary and quests.has(KEY):
		return validate(quests.get(KEY), {})
	return ""

static func release(quests: Dictionary) -> Dictionary:
	quests.erase(KEY)
	return quests

## JSON reads every number back as a float; the saved record is normalized to ints so a save/load round trip compares
## equal (cave_curse_integration, cave_normal_start_test, cave_roach_live_behavior_test).
static func normalized(saved: Dictionary) -> Dictionary:
	var out: Dictionary = {"version": int(saved.get("version", 1)), "areas": {}}
	var areas: Variant = saved.get("areas", {})
	if areas is Dictionary:
		for area in areas:
			var row: Variant = areas[area]
			if not row is Dictionary: continue
			var ids: Array = []
			for raw in row.get("regions", []):
				if raw is int or raw is float: ids.append(int(raw))
			out.areas[str(area)] = {"full": bool(row.get("full", false)), "regions": ids}
	return out

static func taken(state: Dictionary, host_area: String) -> Dictionary:
	if state.has(KEY) and state.get(KEY) is Dictionary:
		return normalized(state.get(KEY) as Dictionary)
	var quests: Variant = state.get("quests")
	if quests is Dictionary and quests.has(KEY) and quests.get(KEY) is Dictionary:
		return normalized(quests.get(KEY) as Dictionary)
	if quests is Dictionary:
		return migrate(quests, host_area)
	return migrate({}, host_area)

static func stored(host: Node) -> Dictionary:
	var saved: Variant = host.get(KEY)
	if saved is Dictionary:
		return (saved as Dictionary).duplicate(true)
	return initial()

static func migrate(quests: Dictionary, host_area: String) -> Dictionary:
	var areas := {}
	if host_area != "":
		areas[host_area] = {"full": true, "regions": []}
	for key in quests.keys():
		var name := str(key)
		if not name.begins_with("act2_creatures_"): continue
		var area := name.trim_prefix("act2_creatures_")
		if area in CREATURE_AREAS and not areas.has(area):
			areas[area] = {"full": true, "regions": []}
	return {"version": 1, "areas": areas}

static func reveal(saved: Dictionary, area: String, ids: Array, mapped: int = -1) -> Dictionary:
	var copy: Dictionary = saved.duplicate(true)
	if area == "": return copy
	if not copy.get("areas") is Dictionary: copy.areas = {}
	var row: Dictionary = {"full": false, "regions": []}
	if copy.areas.has(area) and copy.areas[area] is Dictionary:
		row = (copy.areas[area] as Dictionary).duplicate(true)
	if bool(row.get("full", false)):
		copy.areas[area] = {"full": true, "regions": []}
		return copy
	var seen := {}
	var regions: Array = []
	for raw in row.get("regions", []):
		var id := int(raw)
		if id < 0 or seen.has(id): continue
		seen[id] = true
		regions.append(id)
	for raw in ids:
		var id := int(raw)
		if id < 0 or seen.has(id): continue
		seen[id] = true
		regions.append(id)
	regions.sort()
	if mapped >= 0 and regions.size() >= mapped and mapped > 0:
		copy.areas[area] = {"full": true, "regions": []}
	else:
		copy.areas[area] = {"full": false, "regions": regions}
	return copy

static func attach(map: Node) -> Node:
	if map.get_node_or_null("AtlasExplored") != null: return map.get_node("AtlasExplored")
	var node: Node = load("res://scripts/lol2/atlas_explored.gd").new()
	node.host = map
	node.name = "AtlasExplored"
	map.add_child(node)
	return node

func _ready() -> void:
	var area := area_of(host)
	if area != "":
		nav = preload("res://scripts/lol2/region_visibility.gd").load_regions(area)
	note()

func mapped_count() -> int:
	var count := 0
	for row in nav:
		if row is Array and row.size() > 0 and row[0] is Array and not (row[0] as Array).is_empty():
			count += 1
	return count

func stand_point() -> Vector3:
	var body: Variant = host.get("player")
	if body == null: return Vector3(INF, INF, INF)
	var point: Vector3 = body.global_position
	var shift: Variant = host.get("native_translation")
	if shift is Vector3: point -= shift
	return point

func note() -> void:
	if host == null: return
	var area := area_of(host)
	if area == "": return
	var quests: Dictionary = {}
	if host.get("quest_state") is Dictionary:
		quests = host.quest_state
	if quests.has(KEY):
		if not host.get(KEY) is Dictionary:
			host.set(KEY, (quests[KEY] as Dictionary).duplicate(true))
		quests.erase(KEY)
	if not host.get(KEY) is Dictionary:
		host.set(KEY, migrate(quests, area))
		return
	var ids: Array = []
	var prog: Variant = host.get("progression")
	if prog != null:
		ids.append(int(prog.current_region))
	else:
		var point := stand_point()
		if point.distance_to(last_stand) >= 1.0:
			last_region = -1 if nav.is_empty() else int(preload("res://scripts/lol2/region_visibility.gd").region_at_nav(nav, point))
			last_stand = point
		ids.append(last_region)
	var vis: Variant = host.get("region_visibility")
	if vis != null and vis.get("visible_regions") is Dictionary:
		for key in vis.visible_regions.keys():
			ids.append(int(key))
	var saved: Dictionary = host.get(KEY)
	var next := reveal(saved, area, ids, mapped_count())
	if JSON.stringify(next) != JSON.stringify(saved):
		host.set(KEY, next)

func _process(_delta: float) -> void:
	note()
