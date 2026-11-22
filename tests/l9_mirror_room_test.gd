extends SceneTree
## G3. The Cemetery arrival stands in Ruins region 2306. Region 2301, straight ahead, is the Jungle trip
## and stays. The note is recorded there. The Jungle landing has no neighboring walk back.
const L9 = preload("res://scripts/lol2/l9_journal_hints.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const SENTENCE := "One of these mirrors leads back to the jungle."
const L9_GROUP := 572
const L9_RAW := "020100001cc8"
const L9_FILE := 23384472
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)

func _initialize() -> void:
	run.call_deferred()

class Effects extends Node:
	var data: Dictionary = {}
	func state() -> Dictionary:
		return data

class MapHost extends Node3D:
	var player: Node3D
	var player_form: int = 0
	var quest_state: Dictionary = {}
	var native_translation: Vector3 = Vector3.ZERO
	var item_effects: Node
	var feedback: Array[String] = []
	func save_feedback(text: String) -> void:
		feedback.append(text)

func run() -> void:
	_note()
	_exit()
	_way_back()
	if failures == 0:
		print("PASS l9_mirror_room_test: mirror note on arrival, region 2301 stays the jungle trip, landing has no near return")
	quit(1 if failures else 0)

func _note() -> void:
	var row_text := ""
	for item in L9.JOURNAL_HINTS:
		var row: Dictionary = item
		if str(row.get("when", "")) == "l9_mirror_jungle":
			row_text = str(row.get("hint", ""))
	check(row_text == SENTENCE, "journal sentence")
	check(MyJournal.hints().get("l9_mirror_jungle", "") == SENTENCE, "registered sentence")
	var host := MapHost.new()
	var player := Node3D.new()
	var effects := Effects.new()
	host.player = player
	host.item_effects = effects
	root.add_child(host)
	host.add_child(player)
	host.add_child(effects)
	player.position = Vector3(-3032.0, 232.0, -8232.0)
	var hints: L9 = L9.attach(host) as L9
	check(hints.places().has("mirror"), "arrival is the mirror place")
	check(str(hints.check()) == "l9_mirror_jungle", "first presence records the note")
	check(MyJournal.notes(host) == ["l9_mirror_jungle"], "one journal id")
	check(str(hints.check()) == "", "the note is not repeated")
	player.position = Vector3(-3027.0, 232.0, -8381.0)
	check(not hints.places().has("mirror"), "region 2301 is past the note")
	player.position = Vector3(0.0, 232.0, 0.0)
	check(not hints.places().has("mirror"), "the rest of the ruins is not the note")
	host.native_translation = Vector3(80.0, 0.0, -40.0)
	player.position = Vector3(-3032.0, 232.0, -8232.0) + host.native_translation
	check(hints.places().has("mirror"), "native_translation is subtracted")
	host.free()

func _exit() -> void:
	var ruins: Dictionary = _json("res://scripts/lol2/native_scripts/L9_DR.json")
	var trip: Vector2i = _group_trip(ruins, L9_GROUP)
	check(trip == Vector2i(8, 6), "group 572 is level 8 selector 6")
	check(_group_raw(ruins, L9_GROUP) == L9_RAW, "group 572 raw")
	check(_group_file(ruins, L9_GROUP) == L9_FILE, "group 572 file offset")
	var bound: Array = _region_events(ruins, 2301, L9_GROUP)
	check(bound.size() == 1, "region 2301 fires group 572 once")
	if bound.size() == 1:
		var event: Dictionary = bound[0]
		check(int(event.get("event", -1)) == 2 and int(event.get("kind", -1)) == 12, "region 2301 is an entry event")
		check(event.get("predicate") == null, "region 2301 has no predicate")
		check(str(event.get("raw_hex", "")) == "080c3c02fd080200", "region 2301 raw")
	var maps: Dictionary = _json("res://scripts/lol2/act2_maps.json")
	var arrival: Dictionary = _arrival(maps, "L9_DR", 3)
	check(int(arrival.get("heading_units", -1)) == 0, "selector 3 heading stays 0")
	check(int(arrival.get("x", 0)) == -3032 and int(arrival.get("y", 0)) == 8232, "selector 3 point")
	check(int(arrival.get("region", -1)) == 2306, "selector 3 region")
	check(str(arrival.get("raw_hex", "")) == "28f428200000020903000000", "selector 3 raw")
	var nav: Dictionary = _json("res://assets/lol2/generated/creature_nav/L9_DR.json")
	var floor: float = _floor(nav, 2306)
	check(floor == 200.0, "region 2306 floor")
	check(L9.in_mirror_room(Vector3(-3032.0, floor + 32.0, -8232.0)), "the stand is inside the note")
	check(_contains(nav, -3032.0, -8232.0) == [2306], "the stand is region 2306")
	check(_contains(nav, -3027.0, -8381.0) == [2301], "the exit cell is region 2301")
	var level: String = FileAccess.get_file_as_string("res://scripts/lol2/dragon_level.gd")
	check(level.contains("player.rotation.y = -TAU * float(pose.heading) / 65536.0"), "arrival heading is still applied")

func _way_back() -> void:
	var jungle: Dictionary = _json("res://scripts/lol2/native_scripts/L8_SJ.json")
	var trips: Dictionary = _trips(jungle)
	var back: Array = []
	for event_item in _kind12(jungle):
		var event: Dictionary = event_item
		if int(event.get("event", -1)) != 2:
			continue
		var group_id: int = int(event.get("group", -1))
		if not trips.has(group_id):
			continue
		var trip: Vector2i = trips[group_id] as Vector2i
		if trip.x != 9:
			continue
		var region_id: int = int(event.get("region", -1))
		if region_id not in back:
			back.append(region_id)
	back.sort()
	check(back == [3132, 3569, 3570, 3573], "the jungle returns to the ruins are those four regions")
	var nav: Dictionary = _json("res://assets/lol2/generated/creature_nav/L8_SJ.json")
	var record := Vector2(2063.0, -2326.0)
	var reported := Vector2(2101.0, -2221.0)
	check(_contains(nav, record.x, record.y) == [3539], "arrival 6 stands in region 3539")
	check(_contains(nav, reported.x, reported.y) == [3535, 3537], "the reported stand is regions 3535 and 3537")
	for region_id in back:
		var record_gap: float = _gap(nav, region_id, record)
		var reported_gap: float = _gap(nav, region_id, reported)
		check(record_gap > 1000.0 and reported_gap > 1000.0, "region %d is far from the landing" % region_id)
	var prop: Dictionary = _object(jungle, "prop", 30)
	var prop_groups: Array = []
	for event_item in prop.get("events", []):
		var event: Dictionary = event_item
		if int(event.get("kind", -1)) == 6:
			prop_groups.append(int(event.get("group", -1)))
	check(prop_groups == [1968, 2022, 2076, 2130], "prop 30 has four timers")
	var prop_trips: Array = []
	for group_id in prop_groups:
		if trips.has(int(group_id)):
			prop_trips.append(int(group_id))
	check(prop_trips == [2076] and (trips[2076] as Vector2i) == Vector2i(9, 2), "prop 30's only level change is the far ruins selector 2")
	var maps: Dictionary = _json("res://scripts/lol2/act2_maps.json")
	var landing: Dictionary = _arrival(maps, "L8_SJ", 6)
	check(int(landing.get("x", 0)) == 2063 and int(landing.get("y", 0)) == 2326, "jungle arrival 6 point")
	check(int(landing.get("region", -1)) == 3539 and int(landing.get("heading_units", -1)) == 29127, "jungle arrival 6 region and heading")

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	check(false, "json " + path)
	return {}

func _arrival(maps: Dictionary, area: String, selector: int) -> Dictionary:
	for item in maps.get("maps", []):
		var row: Dictionary = item
		if str(row.get("area", "")) != area:
			continue
		for arrival_item in row.get("arrivals", []):
			var arrival: Dictionary = arrival_item
			if int(arrival.get("selector", -1)) == selector:
				return arrival
	return {}

func _trips(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for item in data.get("groups", []):
		var group: Dictionary = item
		var decoded: Vector2i = _decode(group)
		if decoded.x >= 0:
			out[int(group.get("group", -1))] = decoded
	return out

func _group_trip(data: Dictionary, group_id: int) -> Vector2i:
	return _trips(data).get(group_id, Vector2i(-1, -1))

func _group_raw(data: Dictionary, group_id: int) -> String:
	for item in data.get("groups", []):
		var group: Dictionary = item
		if int(group.get("group", -1)) != group_id:
			continue
		for command_item in group.get("commands", []):
			var command: Dictionary = command_item
			if int(command.get("opcode", -1)) == 2:
				return str(command.get("raw_hex", ""))
	return ""

func _group_file(data: Dictionary, group_id: int) -> int:
	for item in data.get("groups", []):
		var group: Dictionary = item
		if int(group.get("group", -1)) != group_id:
			continue
		for command_item in group.get("commands", []):
			var command: Dictionary = command_item
			if int(command.get("opcode", -1)) == 2:
				return int(command.get("file_offset", -1))
	return -1

func _decode(group: Dictionary) -> Vector2i:
	for command_item in group.get("commands", []):
		var command: Dictionary = command_item
		if int(command.get("opcode", -1)) != 2:
			continue
		var bytes: PackedByteArray = str(command.get("raw_hex", "")).hex_decode()
		if bytes.size() >= 6 and bytes[4] == 0x1C:
			return Vector2i(int(bytes[5]) & 0x1F, int(bytes[5]) >> 5)
	return Vector2i(-1, -1)

func _kind12(data: Dictionary) -> Array:
	var found: Array = []
	_walk(data.get("region_lists"), found)
	_walk(data.get("objects"), found)
	return found

func _walk(node: Variant, found: Array) -> void:
	if node is Dictionary:
		var row: Dictionary = node
		if int(row.get("kind", -1)) == 12 and row.has("region") and row.has("group") and row.has("event"):
			found.append(row)
		for key in row.keys():
			_walk(row[key], found)
	elif node is Array:
		var rows: Array = node
		for child in rows:
			_walk(child, found)

func _region_events(data: Dictionary, region_id: int, group_id: int) -> Array:
	var found: Array = []
	var seen: Dictionary = {}
	for event_item in _kind12(data):
		var event: Dictionary = event_item
		if int(event.get("region", -1)) != region_id or int(event.get("group", -1)) != group_id:
			continue
		var key := "%d:%d:%d" % [int(event.get("region", -1)), int(event.get("event", -1)), int(event.get("file_offset", -1))]
		if seen.has(key):
			continue
		seen[key] = true
		found.append(event)
	return found

func _object(data: Dictionary, table: String, index: int) -> Dictionary:
	for item in data.get("objects", []):
		var row: Dictionary = item
		if str(row.get("table", "")) == table and int(row.get("index", -1)) == index:
			return row
	return {}

func _floor(nav: Dictionary, index: int) -> float:
	var regions: Array = nav.get("regions", [])
	var row: Array = regions[index]
	return float(row[1])

func _contains(nav: Dictionary, x: float, z: float) -> Array:
	var hits: Array = []
	var regions: Array = nav.get("regions", [])
	for index in regions.size():
		var row: Variant = regions[index]
		if not row is Array:
			continue
		var region: Array = row
		if region.is_empty() or not region[0] is Array:
			continue
		var quad: Array = region[0]
		if quad.is_empty():
			continue
		var min_x: float = INF
		var max_x: float = -INF
		var min_z: float = INF
		var max_z: float = -INF
		var usable := false
		for point_item in quad:
			if not point_item is Array:
				continue
			var point: Array = point_item
			if point.size() < 2:
				continue
			usable = true
			min_x = minf(min_x, float(point[0]))
			max_x = maxf(max_x, float(point[0]))
			min_z = minf(min_z, float(point[1]))
			max_z = maxf(max_z, float(point[1]))
		if usable and x >= min_x and x <= max_x and z >= min_z and z <= max_z:
			hits.append(index)
	return hits

func _gap(nav: Dictionary, index: int, point: Vector2) -> float:
	var regions: Array = nav.get("regions", [])
	var region: Array = regions[index]
	var quad: Array = region[0]
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for point_item in quad:
		var corner: Array = point_item
		min_x = minf(min_x, float(corner[0]))
		max_x = maxf(max_x, float(corner[0]))
		min_z = minf(min_z, float(corner[1]))
		max_z = maxf(max_z, float(corner[1]))
	var dx: float = 0.0
	if point.x < min_x:
		dx = min_x - point.x
	elif point.x > max_x:
		dx = point.x - max_x
	var dz: float = 0.0
	if point.y < min_z:
		dz = min_z - point.y
	elif point.y > max_z:
		dz = point.y - max_z
	return sqrt(dx * dx + dz * dz)
