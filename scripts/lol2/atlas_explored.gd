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
## Owner r19p 2026-11-17 (F10 14-11-30, Jungle): 'the map discovery rate is a bit low, perhaps 2x or 3x'. A map without
## a renderer visible set (the Act 1 maps: Jungle, Hive, Dark Halls; not Cave or Museum, see REVEAL_SKIP) revealed only the region under the feet - a
## trail about one region wide (median region 130 across). It now also reveals every region whose centre lies within
## REVEAL_RADIUS of the feet and REVEAL_HEIGHT of their height: a trail about 400 wide, three times the old one.
const REVEAL_RADIUS := 200.0
const REVEAL_HEIGHT := 96.0
const REVEAL_STEP := 32.0
const BUCKET := 256.0
## Cave and Museum keep the stood-region rule for now: on the Cave a 200 radius opens the Atlas zoomed out so far that
## the arrival floor is a dot, and on the Museum it reveals every room the arrival walk can reach (atlas_readable_cave and
## atlas_readable_museum). The owner's report was the Jungle.
const REVEAL_SKIP := ["L1_DC", "L3_DH"]
var centres: PackedVector3Array = PackedVector3Array()
var buckets: Dictionary = {}
var near: Array = []
var near_at := Vector3(INF, INF, INF)
var known: Dictionary = {}
var known_for: Variant = null
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
	centres.resize(nav.size())
	for i in nav.size():
		var row: Variant = nav[i]
		centres[i] = Vector3(INF, INF, INF)
		if not row is Array or row.size() < 2 or not row[0] is Array or (row[0] as Array).is_empty(): continue
		var c := Vector2.ZERO
		for v in row[0]: c += Vector2(float(v[0]), float(v[1]))
		c /= float((row[0] as Array).size())
		centres[i] = Vector3(c.x, float(row[1]), c.y)
		var cell := Vector2i(floori(c.x / BUCKET), floori(c.y / BUCKET))
		if not buckets.has(cell): buckets[cell] = PackedInt32Array()
		buckets[cell].append(i)
	# Derived hosts finish native arrival placement after the base attaches this node.
	# Sampling inline here recorded the temporary pack spawn as explored.
	note.call_deferred()

func mapped_count() -> int:
	var count := 0
	for row in nav:
		if row is Array and row.size() > 0 and row[0] is Array and not (row[0] as Array).is_empty():
			count += 1
	return count

## Regions whose centre is within REVEAL_RADIUS (flat) and REVEAL_HEIGHT of the point; recomputed after REVEAL_STEP.
func near_regions(point: Vector3) -> Array:
	if point.distance_to(near_at) < REVEAL_STEP: return near
	near_at = point
	near = []
	var r := ceili(REVEAL_RADIUS / BUCKET)
	var home := Vector2i(floori(point.x / BUCKET), floori(point.z / BUCKET))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var cell := home + Vector2i(dx, dz)
			if not buckets.has(cell): continue
			for i in buckets[cell]:
				var c: Vector3 = centres[i]
				if Vector2(c.x - point.x, c.z - point.z).length() <= REVEAL_RADIUS and absf(c.y - point.y) <= REVEAL_HEIGHT: near.append(i)
	return near

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
	elif prog == null and not nav.is_empty() and not area in REVEAL_SKIP:
		ids.append_array(near_regions(stand_point()))
	var saved: Dictionary = host.get(KEY)
	# Nothing new in sight: skip the whole-record copy and compare (it ran every frame and grows with the explored set).
	if is_same(saved, known_for):
		var fresh := false
		for raw in ids:
			if int(raw) >= 0 and not known.has(int(raw)): fresh = true; break
		if not fresh: return
	var next := reveal(saved, area, ids, mapped_count())
	if JSON.stringify(next) != JSON.stringify(saved):
		host.set(KEY, next)
		saved = next
	known_for = saved
	known = {}
	var row: Variant = (saved.get("areas", {}) as Dictionary).get(area)
	if row is Dictionary:
		if bool(row.get("full", false)):
			for i in nav.size(): known[i] = true
		for raw in row.get("regions", []): known[int(raw)] = true

func _process(_delta: float) -> void:
	note()
