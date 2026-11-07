extends Control
## Geometry overview, not a reconstruction of native automap discovery rules.
var walkthrough: Node3D
var geometry_path := "res://assets/lol2/generated/museum_review/museum.json"
## World-space offset added to source x/z (the Cave places its source geometry at native_translation).
var origin_offset := Vector2.ZERO
var edges: Array = []
var floor_polygons: Array[PackedVector2Array] = []
var bounds := Rect2()
var zoom := 1.0
var pan := Vector2.ZERO
var slices: Array = []
var slice_area := ""
var storey_of: Dictionary = {}
var storey_lo := 0
var storey_hi := 0
var storey_offset := 0
const FADE_ALPHA := 0.15
const SECTION_AREAS := ["L9_DR", "L10_DC", "L16_CA", "L14_HT"]
const SECTION_CELL := 512.0
const SECTION_MARGIN := 1.0
var section_of: Dictionary = {}
var section_hi := 0
var section_offset := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = "Scroll to zoom · Drag to move · PgUp and PgDn change storey · Section steps through a piled room"
	var data = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	var perimeter := {}
	# Review geometry ("faces": floor polygons in world x/z) or a creature-navigation graph ("regions": source
	# region quads in x/z), the latter for areas without a faces export (the Cave).
	var floors: Array = []
	if data.has("faces"):
		for face in data.faces:
			if face.kind != "floor": continue
			var points := PackedVector2Array()
			for p in face.points: points.append(Vector2(p[0],p[2]))
			floors.append(points)
	else:
		for region in data.regions:
			var points := PackedVector2Array()
			for p in region[0]: points.append(Vector2(p[0],p[1]))
			floors.append(points)
	for source_polygon in floors:
		var polygon := PackedVector2Array()
		for p in source_polygon: polygon.append(p + origin_offset)
		var area := 0.0
		for i in polygon.size(): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(area) < 0.02: continue
		floor_polygons.append(polygon)
		for i in polygon.size():
			var start := polygon[i]
			var end := polygon[(i+1)%polygon.size()]
			if start.distance_to(end) < 0.1: continue
			if perimeter.is_empty(): bounds = Rect2(start,Vector2.ZERO)
			bounds = bounds.expand(start).expand(end)
			if start.x > end.x or (start.x == end.x and start.y > end.y):
				var swap := start
				start = end
				end = swap
			var key := Vector4(start.x,start.y,end.x,end.y)
			if perimeter.has(key): perimeter[key].count += 1
			else: perimeter[key] = {"a":start,"b":end,"count":1}
	for edge in perimeter.values():
		if edge.count == 1: edges.append([edge.a,edge.b])
	_index_storeys(data)

func _process(_delta: float) -> void:
	queue_redraw()

func map_point(point: Vector2) -> Vector2:
	var scale_factor := minf((size.x - 24) / maxf(bounds.size.x, 1), (size.y - 24) / maxf(bounds.size.y, 1))
	return (point - bounds.get_center()) * scale_factor * zoom + size / 2 + pan

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("171d20"))
	if slices.is_empty():
		for polygon in floor_polygons:
			var mapped := PackedVector2Array()
			for point in polygon: mapped.append(map_point(point))
			draw_colored_polygon(mapped, fill_color())
		for edge in edges:
			draw_line(map_point(edge[0]), map_point(edge[1]), Color("090f12"), 5, true)
			draw_line(map_point(edge[0]), map_point(edge[1]), Color("b3bb95"), 1.5, true)
	else:
		var viewed := viewed_storey()
		var here := _player_region()
		var filtering := use_filter()
		var viewed_section := _depth_at(here)
		for item in slices:
			var storey := int(item.storey)
			if storey < 0: continue
			var kind := "bright" if viewed < 0 else band(storey, viewed)
			if kind == "hidden": continue
			if section_hi > 0 and viewed_section >= 0 and int(item.get("section", 0)) != viewed_section: continue
			if filtering and not _shown(int(item.region), here): continue
			var color := fill_color() if kind == "bright" else fade_color()
			var mapped := PackedVector2Array()
			for point in item.polygon: mapped.append(map_point(point))
			if mapped.size() >= 3: draw_colored_polygon(mapped, color)
			for i in mapped.size():
				draw_line(mapped[i], mapped[(i + 1) % mapped.size()], color, 1.0, true)
	if not is_instance_valid(walkthrough): return
	var position_3d: Vector3 = walkthrough.player.global_position
	var point := map_point(Vector2(position_3d.x, position_3d.z))
	var forward: Vector3 = -walkthrough.player.global_basis.z
	draw_circle(point, 4, Color("e5be72"))
	draw_line(point, point + Vector2(forward.x, forward.z) * 14, Color("e5be72"), 2)

func zoom_at(factor: float, anchor: Vector2) -> void:
	var next_zoom := clampf(zoom * factor, 1.0, 12.0)
	pan = anchor - size / 2 - (anchor - size / 2 - pan) * next_zoom / zoom
	zoom = next_zoom
	queue_redraw()

func overview() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func center_player() -> void:
	if not is_instance_valid(walkthrough): return
	zoom = maxf(zoom, 3.0)
	var position_3d: Vector3 = walkthrough.player.global_position
	pan += size / 2 - map_point(Vector2(position_3d.x, position_3d.z))
	queue_redraw()

func browse(step: int) -> void:
	storey_offset += step
	queue_redraw()

static func section_name(depth: int) -> String:
	if depth <= 0:
		return "Floor"
	return "Inside %d" % depth

## A section is how many same-storey rooms contain this region's vertex-mean centroid.
## Negative cells use floor(), because int() truncates toward zero.
static func section_depths(regions: Array) -> Array:
	var count := regions.size()
	var grouped: Array = group_storeys(regions)
	var areas: Array = []
	var means: Array = []
	var polygons: Array = []
	var live: Array = []
	var polygon := PackedVector2Array()
	var mean := Vector2.ZERO
	var cell := Vector2i.ZERO
	var bucket: Array = []
	areas.resize(count)
	means.resize(count)
	polygons.resize(count)
	live.resize(count)
	var grid: Dictionary = {}
	for index in count:
		live[index] = false
		var row: Array = regions[index]
		var source: Array = row[0]
		var storey := int(grouped[index].storey)
		if source.size() < 3 or storey < 0:
			continue
		polygon = PackedVector2Array()
		var total := Vector2.ZERO
		for point in source:
			var vertex := Vector2(float(point[0]), float(point[1]))
			polygon.append(vertex)
			total += vertex
		var area := _polygon_area(polygon)
		if area <= 0.0:
			continue
		mean = total / float(polygon.size())
		areas[index] = area
		means[index] = mean
		polygons[index] = polygon
		live[index] = true
		var least := polygon[0]
		var most := polygon[0]
		for vertex in polygon:
			least.x = minf(least.x, vertex.x)
			least.y = minf(least.y, vertex.y)
			most.x = maxf(most.x, vertex.x)
			most.y = maxf(most.y, vertex.y)
		var x0 := int(floor(least.x / SECTION_CELL))
		var x1 := int(floor(most.x / SECTION_CELL))
		var y0 := int(floor(least.y / SECTION_CELL))
		var y1 := int(floor(most.y / SECTION_CELL))
		for gx in range(x0, x1 + 1):
			for gy in range(y0, y1 + 1):
				cell = Vector2i(gx, gy)
				if not grid.has(cell):
					grid[cell] = []
				bucket = grid[cell]
				bucket.append(index)
	var cover: Dictionary = {}
	for index in count:
		if not live[index]:
			continue
		mean = means[index]
		cell = Vector2i(int(floor(mean.x / SECTION_CELL)), int(floor(mean.y / SECTION_CELL)))
		var best := -1
		var best_area := 0.0
		bucket = grid.get(cell, [])
		for other in bucket:
			var candidate := int(other)
			if candidate == index or not live[candidate]:
				continue
			if int(grouped[candidate].storey) != int(grouped[index].storey):
				continue
			var other_area := float(areas[candidate])
			if other_area <= float(areas[index]):
				continue
			polygon = polygons[candidate]
			if not _inside(mean, polygon, SECTION_MARGIN):
				continue
			if best < 0 or other_area < best_area or (is_equal_approx(other_area, best_area) and candidate < best):
				best = candidate
				best_area = other_area
		if best >= 0:
			cover[index] = best
	var depths: Array = []
	depths.resize(count)
	for index in count:
		depths[index] = -1 if not live[index] else _chain_depth(index, cover, count)
	return depths

static func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	var count := polygon.size()
	for i in count:
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % count]
		area += a.cross(b)
	return absf(area) * 0.5

static func _inside(point: Vector2, polygon: PackedVector2Array, margin: float) -> bool:
	if polygon.size() < 3:
		return false
	if not Geometry2D.is_point_in_polygon(point, polygon):
		return false
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= margin:
			return false
	return true

static func _chain_depth(region: int, cover: Dictionary, guard: int) -> int:
	var depth := 0
	var seen: Dictionary = {}
	var current := region
	while cover.has(current) and depth < guard:
		if seen.has(current):
			return 0
		seen[current] = true
		current = int(cover[current])
		depth += 1
	return depth

func browse_section(step: int) -> void:
	if section_hi <= 0:
		return
	var region := _player_region()
	var base := 0
	if region >= 0 and section_of.has(region):
		var depth := int(section_of[region])
		if depth >= 0:
			base = depth
	var here := clampi(base + section_offset, 0, section_hi)
	var span := section_hi + 1
	var nxt := posmod(here + step, span)
	section_offset = nxt - base
	queue_redraw()

func _depth_at(region: int) -> int:
	if section_hi <= 0:
		return -1
	if region < 0 or not section_of.has(region):
		return -1
	var here := int(section_of[region])
	if here < 0:
		return -1
	return clampi(here + section_offset, 0, section_hi)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEUP:
			browse(1)
			accept_event()
			return
		if event.keycode == KEY_PAGEDOWN:
			browse(-1)
			accept_event()
			return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(1.25, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(0.8, event.position)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pan += event.relative
		queue_redraw()
		accept_event()

static func fill_color() -> Color:
	return Color("64765d")

static func fade_color() -> Color:
	var fill := fill_color()
	return Color(fill.r, fill.g, fill.b, FADE_ALPHA)

static func band(storey: int, viewed: int) -> String:
	var gap := absi(storey - viewed)
	if gap == 0: return "bright"
	if gap == 1: return "faded"
	return "hidden"

static func _find_root(parent: Array, index: int) -> int:
	while int(parent[index]) != index:
		parent[index] = int(parent[int(parent[index])])
		index = int(parent[index])
	return index

static func _union(parent: Array, left: int, right: int) -> void:
	var root_left := _find_root(parent, left)
	var root_right := _find_root(parent, right)
	if root_left != root_right:
		parent[root_right] = root_left

static func _median(values: Array) -> float:
	var ordered: Array = values.duplicate()
	ordered.sort()
	var count := ordered.size()
	if count == 0: return 0.0
	var mid := int(count / 2.0)
	if count % 2: return float(ordered[mid])
	return (float(ordered[mid - 1]) + float(ordered[mid])) / 2.0

static func group_storeys(regions: Array) -> Array:
	var count := regions.size()
	var parent: Array = []
	parent.resize(count)
	var floors: Array = []
	floors.resize(count)
	var empty: Array = []
	empty.resize(count)
	for index in count:
		parent[index] = index
		var row: Array = regions[index]
		var polygon: Array = row[0]
		floors[index] = float(row[1])
		empty[index] = polygon.is_empty()
	for index in count:
		if empty[index]: continue
		var row: Array = regions[index]
		var floor := float(floors[index])
		for edge in row[3]:
			if not edge is Array or edge.is_empty(): continue
			var other := int(edge[0])
			if other < 0 or other >= count or other == index: continue
			var other_poly: Array = regions[other][0]
			if other_poly.is_empty(): continue
			if absf(floor - float(regions[other][1])) > 32.0: continue
			_union(parent, index, other)
	var components: Dictionary = {}
	for index in count:
		if empty[index]: continue
		var root := _find_root(parent, index)
		if not components.has(root): components[root] = []
		components[root].append(index)
	var ordered: Array = []
	for ids in components.values():
		var samples: Array = []
		var least: int = ids[0]
		for id in ids:
			samples.append(floors[id])
			least = mini(least, int(id))
		ordered.append({"ids": ids, "median": _median(samples), "min_id": least})
	for i in range(1, ordered.size()):
		var item: Dictionary = ordered[i]
		var j := i - 1
		while j >= 0 and (float(ordered[j].median) > float(item.median) or (is_equal_approx(float(ordered[j].median), float(item.median)) and int(ordered[j].min_id) > int(item.min_id))):
			ordered[j + 1] = ordered[j]
			j -= 1
		ordered[j + 1] = item
	var storey_at: Dictionary = {}
	for number in ordered.size():
		for region in ordered[number].ids:
			storey_at[region] = number
	var rows: Array = []
	for index in count:
		rows.append({"region": index, "storey": -1 if empty[index] else int(storey_at[index])})
	return rows

func _index_storeys(data: Variant) -> void:
	slices = []
	storey_of = {}
	slice_area = ""
	section_of = {}
	section_hi = 0
	section_offset = 0
	if is_instance_valid(walkthrough):
		slice_area = preload("res://scripts/lol2/atlas_explored.gd").area_of(walkthrough)
	var regions: Array = []
	if slice_area != "":
		var path := "res://assets/lol2/generated/creature_nav/%s.json" % slice_area
		if FileAccess.file_exists(path):
			var nav: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if nav is Dictionary and nav.get("regions") is Array:
				regions = nav.regions
	if regions.is_empty() and data is Dictionary and data.has("regions"):
		regions = data.regions
		if slice_area == "" and geometry_path.ends_with("L1_DC.json"):
			slice_area = "L1_DC"
	if regions.is_empty(): return
	var grouped: Array = group_storeys(regions)
	var seen_storey := false
	for index in regions.size():
		var row: Array = regions[index]
		var source: Array = row[0]
		if source.is_empty(): continue
		var polygon := PackedVector2Array()
		for point in source:
			polygon.append(Vector2(float(point[0]), float(point[1])) + origin_offset)
		var storey := int(grouped[index].storey)
		slices.append({"polygon": polygon, "region": index, "storey": storey, "floor": float(row[1])})
		storey_of[index] = storey
		if storey < 0: continue
		if not seen_storey:
			storey_lo = storey
			storey_hi = storey
			seen_storey = true
		else:
			storey_lo = mini(storey_lo, storey)
			storey_hi = maxi(storey_hi, storey)
	if slice_area in SECTION_AREAS:
		var depths: Array = section_depths(regions)
		for item in slices:
			var region := int(item.region)
			var depth := int(depths[region])
			item.section = depth
			section_of[region] = depth
			if depth > section_hi:
				section_hi = depth

func _player_region() -> int:
	if not is_instance_valid(walkthrough): return -1
	var body: Variant = walkthrough.get("player")
	if body == null: return -1
	var flat := Vector2(body.global_position.x, body.global_position.z)
	var best := -1
	var best_dy := INF
	for item in slices:
		var polygon: PackedVector2Array = item.polygon
		if polygon.size() < 3: continue
		if not Geometry2D.is_point_in_polygon(flat, polygon): continue
		var dy := absf(body.global_position.y - float(item.floor))
		if dy < best_dy:
			best_dy = dy
			best = int(item.region)
	return best

func viewed_storey() -> int:
	var region := _player_region()
	if region < 0 or not storey_of.has(region): return -1
	var here := int(storey_of[region])
	if here < 0: return -1
	return clampi(here + storey_offset, storey_lo, storey_hi)

func _atlas_saved() -> Variant:
	if not is_instance_valid(walkthrough): return null
	var direct: Variant = walkthrough.get("atlas_explored")
	if direct is Dictionary: return direct
	var quests: Variant = walkthrough.get("quest_state")
	if quests is Dictionary and quests.get("atlas_explored") is Dictionary: return quests.atlas_explored
	return null

func use_filter() -> bool:
	if slice_area == "" or not is_instance_valid(walkthrough): return false
	if walkthrough.get_node_or_null("AtlasExplored") != null: return true
	var saved: Variant = _atlas_saved()
	if saved is Dictionary:
		var areas: Variant = saved.get("areas", {})
		return areas is Dictionary and areas.has(slice_area)
	return false

func _shown(region: int, player_region: int) -> bool:
	if region == player_region: return true
	var saved: Variant = _atlas_saved()
	if not saved is Dictionary:
		var quests: Variant = walkthrough.get("quest_state")
		if not quests is Dictionary: return true
		var migrated: Dictionary = preload("res://scripts/lol2/atlas_explored.gd").migrate(quests, slice_area)
		return bool(migrated.areas.get(slice_area, {}).get("full", false))
	var areas: Variant = saved.get("areas", {})
	if not areas is Dictionary or not areas.has(slice_area): return false
	var row: Dictionary = areas[slice_area]
	if bool(row.get("full", false)): return true
	for raw in row.get("regions", []):
		if int(raw) == region: return true
	return false
