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
## Floor step linked neighbours may differ by and still share a storey (a ramp); larger steps between overlapping regions make a pile.
const STOREY_STEP := 32.0
var section_of: Dictionary = {}
var section_hi := 0
var section_offset := 0
## Readable Atlas (owner 2026-11-08, AI_COMMS/ATLAS_READABLE_20261108.md): explored regions draw their wall sides as lines
## (a polygon side with no linked neighbour in creature_nav), linked sides stay open; named places and level exits from
## atlas_places.gd show once a region near them is explored; plot markers for discovered Journal notes; legend, north and
## the player arrow. Classic and Enhanced alike; the Atlas never pauses the game.
const Places := preload("res://scripts/lol2/atlas_places.gd")
const WALL_COLOR := Color("d8d2b4")
const WALL_FADE := Color(0.85, 0.82, 0.71, 0.25)
const EXIT_COLOR := Color("7fc8e8")
const PLACE_COLOR := Color("e5be72")
const PLOT_COLOR := Color("e87d6b")
const LABEL_SIZE := 12
const MAX_ZOOM := 512.0 # A fresh Cave region is tiny relative to the complete north/south map.
var readable := true
var last_report: Dictionary = {}
## Native player-impassable regions (region word +0x1C bit0; assets/lol2/generated/region_blockers/<AREA>.json): the
## Jungle's thickets and the rock of the caves. They are not floor on the map, and a side toward one is a wall line.
var blocked: Dictionary = {}

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
		var drawn_walls := 0
		for item in slices:
			var storey := int(item.storey)
			if storey < 0: continue
			var kind := "bright" if viewed < 0 else band(storey, viewed)
			if kind == "hidden": continue
			# A piled area's other floor is another storey (PgUp / PgDn). Painting it here put the cemetery over the catacombs.
			if section_hi > 0 and viewed >= 0 and storey != viewed: continue
			if section_hi > 0 and viewed_section >= 0 and int(item.get("section", 0)) != viewed_section: continue
			if readable and bool(item.get("blocked", false)): continue
			if filtering and not _shown(int(item.region), here): continue
			var color := fill_color() if kind == "bright" else fade_color()
			var mapped := PackedVector2Array()
			for point in item.polygon: mapped.append(map_point(point))
			# Thin native quads can collapse at Atlas scale. Keep their edges; fill only a triangulable screen polygon.
			if bool(item.get("can_fill", mapped.size() >= 3)) and not Geometry2D.triangulate_polygon(mapped).is_empty():
				draw_colored_polygon(mapped, color)
			for i in mapped.size():
				draw_line(mapped[i], mapped[(i + 1) % mapped.size()], color, 1.0, true)
			if readable:
				var wall_color := WALL_COLOR if kind == "bright" else WALL_FADE
				for side in item.walls:
					var i := int(side)
					draw_line(mapped[i], mapped[(i + 1) % mapped.size()], wall_color, 2.0 if kind == "bright" else 1.0, true)
					drawn_walls += 1
		if readable: _draw_readable(filtering, here, drawn_walls)
	if not is_instance_valid(walkthrough): return
	var position_3d: Vector3 = walkthrough.player.global_position
	var point := map_point(Vector2(position_3d.x, position_3d.z))
	var forward: Vector3 = -walkthrough.player.global_basis.z
	draw_circle(point, 4, Color("e5be72"))
	draw_line(point, point + Vector2(forward.x, forward.z) * 14, Color("e5be72"), 2)

## Polygon sides of a creature_nav row with no walkable neighbour: no linked edge there (row[3] edges carry the neighbour
## and the side midpoint), or the neighbour is a blocked region.
static func wall_sides(row: Array, impassable: Dictionary) -> Array:
	var sides: Array = []
	var source: Array = row[0]
	var edges: Array = row[3] if row.size() > 3 and row[3] is Array else []
	for i in source.size():
		var a := Vector2(float(source[i][0]), float(source[i][1]))
		var b := Vector2(float(source[(i + 1) % source.size()][0]), float(source[(i + 1) % source.size()][1]))
		var middle := (a + b) / 2.0
		var linked := false
		for edge in edges:
			if edge is Array and (edge as Array).size() >= 3 and middle.distance_to(Vector2(float(edge[1]), float(edge[2]))) <= 2.0:
				linked = not impassable.has(int(edge[0]))
				break
		if not linked: sides.append(i)
	return sides

## Explored region ids of this area (all when the area is full or unfiltered).
func _explored_regions() -> Dictionary:
	var out := {}
	var saved: Variant = _atlas_saved()
	if saved is Dictionary and (saved.get("areas", {}) as Dictionary).has(slice_area):
		var row: Dictionary = saved.areas[slice_area]
		if bool(row.get("full", false)):
			out["full"] = true
			return out
		for raw in row.get("regions", []): out[int(raw)] = true
	return out

## A place shows once an explored region's polygon comes within `reveal` of it (or the area is full / unfiltered).
func place_revealed(place: Dictionary, explored: Dictionary, filtering: bool, here: int) -> bool:
	if not filtering or explored.has("full"): return true
	var at := Vector2(float(place.x), float(place.z)) + origin_offset
	var reveal := float(place.get("reveal", 100.0))
	for item in slices:
		var region := int(item.region)
		if bool(item.get("blocked", false)) or (region != here and not explored.has(region)): continue
		var polygon: PackedVector2Array = item.polygon
		if polygon.size() < 3: continue
		if Geometry2D.is_point_in_polygon(at, polygon): return true
		for i in polygon.size():
			if Geometry2D.get_closest_point_to_segment(at, polygon[i], polygon[(i + 1) % polygon.size()]).distance_to(at) <= reveal: return true
	return false

## Zoom and pan so the explored part fills the map (owner 2026-11-08: readable); a full or unfiltered area shows all of it.
func fit_explored() -> void:
	if slices.is_empty() or size.x <= 0 or size.y <= 0:
		overview()
		return
	var explored := _explored_regions()
	if explored.has("full") or not use_filter():
		overview()
		return
	var here := _player_region()
	var viewed := viewed_storey()
	var viewed_section := _depth_at(here)
	var box := Rect2()
	var seen := false
	for item in slices:
		var region := int(item.region)
		if bool(item.get("blocked", false)) or (region != here and not explored.has(region)): continue
		if section_hi > 0 and viewed >= 0 and int(item.storey) != viewed: continue
		if section_hi > 0 and viewed_section >= 0 and int(item.get("section", 0)) != viewed_section: continue
		for point in item.polygon:
			if not seen:
				box = Rect2(point, Vector2.ZERO)
				seen = true
			else: box = box.expand(point)
	if not seen or box.size.x < 1.0 or box.size.y < 1.0:
		center_player()
		return
	var scale_factor := minf((size.x - 24) / maxf(bounds.size.x, 1), (size.y - 24) / maxf(bounds.size.y, 1))
	# The free panel: everything under the legend box, with a margin for the labels.
	var top := _legend_size().y + 8.0
	var free := Rect2(Vector2(28.0, top + 10.0), Vector2(size.x - 56.0, size.y - top - 20.0))
	if free.size.x < 40.0 or free.size.y < 40.0:
		center_player()
		return
	zoom = clampf(minf(free.size.x / (box.size.x * scale_factor), free.size.y / (box.size.y * scale_factor)), 1.0, MAX_ZOOM)
	# map_point(c) lands on the free rect's centre.
	pan = free.get_center() - size / 2.0 - (box.get_center() - bounds.get_center()) * scale_factor * zoom
	queue_redraw()

var _label_boxes: Array = []
## Draws a label unless it would cover one drawn earlier this frame (then it steps down up to three rows, else only the mark stays).
func _place_label(font: Font, at: Vector2, text: String, color: Color) -> bool:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	# A label that would run off the right edge goes to the left of its mark.
	if at.x + width > size.x - 4.0: at.x = at.x - width - 18.0
	for step in 2:
		var origin := at + Vector2(0, step * (LABEL_SIZE + 3))
		var box := Rect2(origin - Vector2(0, LABEL_SIZE), Vector2(width, LABEL_SIZE + 2))
		var free := true
		for other in _label_boxes:
			if (other as Rect2).intersects(box):
				free = false
				break
		if free:
			_label_boxes.append(box)
			_label(font, origin, text, color)
			return true
	return false

## A marker outside the map keeps to the border, so a far plot point still points the way.
func _inside_map(at: Vector2) -> Vector2:
	return Vector2(clampf(at.x, 14.0, size.x - 14.0), clampf(at.y, 14.0, size.y - 14.0))

## Storey of the region under a map point (-1 when no region polygon holds it).
## A point in a pile prefers the storey on screen, so a label for this floor is not marked as the floor above.
func _storey_at(world: Vector2) -> int:
	var viewed := viewed_storey()
	var fallback := -1
	for item in slices:
		var polygon: PackedVector2Array = item.polygon
		if polygon.size() < 3 or int(item.storey) < 0: continue
		if not Geometry2D.is_point_in_polygon(world, polygon): continue
		var storey := int(item.storey)
		if storey == viewed: return storey
		if fallback < 0: fallback = storey
	return fallback

## True when a polygon of `storey` that contains `world` lies over a polygon of `other`.
## Shared edges do not count. A place whose room does not cover the page on screen is not a pile.
func _overlaps_storey(world: Vector2, storey: int, other: int) -> bool:
	var owned: Array[PackedVector2Array] = []
	for item in slices:
		if int(item.storey) != storey: continue
		var polygon: PackedVector2Array = item.polygon
		if polygon.size() < 3: continue
		if Geometry2D.is_point_in_polygon(world, polygon):
			owned.append(polygon)
	if owned.is_empty(): return false
	for item in slices:
		if int(item.storey) != other: continue
		var polygon: PackedVector2Array = item.polygon
		if polygon.size() < 3: continue
		for index in owned.size():
			if _polygons_overlap(owned[index], polygon): return true
	return false

## What the readable Atlas shows right now (tests read it): place ids, exit ids, plot note ids, wall count.
func readable_report() -> Dictionary:
	return last_report.duplicate(true)

func _notes() -> Array:
	if not is_instance_valid(walkthrough): return []
	return preload("res://scripts/lol2/my_journal.gd").notes(walkthrough)

## Museum/Hive mechanisms predate quest_state: read their live saved owner packets without writing quest progress.
func _plot_state() -> Dictionary:
	if not is_instance_valid(walkthrough): return {}
	var raw: Variant = walkthrough.get("quest_state")
	var state: Dictionary = raw.duplicate() if raw is Dictionary else {}
	if slice_area == "L3_DH":
		for pair in [["key_locks", "museum_key_locks"], ["museum_torches", "museum_torches"]]:
			var owner: Variant = walkthrough.get(pair[0])
			if is_instance_valid(owner): state[pair[1]] = owner.state
	elif slice_area == "L5_HC":
		var owner: Variant = walkthrough.get("elevator")
		if is_instance_valid(owner): state["hive_elevator"] = owner.checkpoint
	return state

## Legend rows: four fixed rows plus one per active Journal marker (full text lives here, the map shows the place).
func _legend_rows() -> Array:
	var rows: Array = []
	var quests := _plot_state()
	for marker in Places.active_plot(slice_area, _notes(), quests):
		var place_name: String = str(Places.place(slice_area, str(marker.place)).get("name", ""))
		rows.append("%s: %s" % [place_name, str(marker.label)] if not place_name.is_empty() else str(marker.label))
	return rows

func _legend_size() -> Vector2:
	var font: Font = ThemeDB.fallback_font
	var width := 150.0
	for text in ["wall  ·  gaps are open ways", "place", "way to another area", "what I have heard of  ·  gold: me"] + _legend_rows():
		width = maxf(width, font.get_string_size(str(text), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x)
	var rows := 4 + mini(_legend_rows().size(), 4)
	return Vector2(width + 34.0, rows * (LABEL_SIZE + 3) + 12.0)

func _draw_readable(filtering: bool, here: int, drawn_walls: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var explored := _explored_regions()
	# The legend box (top left) and the north box (top right) are reserved first, so no label lands on them.
	var legend := Rect2(Vector2(4, 4), _legend_size())
	var north_box := Rect2(Vector2(size.x - 34, 4), Vector2(30, 44))
	_label_boxes = [legend, north_box]
	var shown_places: Array = []
	var shown_exits: Array = []
	var ordered: Array = []
	# Ways out first (they must stay readable), then places; a label that would collide steps down once or stays off.
	for place in Places.places(slice_area):
		if not place_revealed(place, explored, filtering, here): continue
		if str(place.get("kind", "place")) == "exit": ordered.push_front(place)
		else: ordered.append(place)
	var viewed := viewed_storey()
	for place in ordered:
		var world := Vector2(float(place.x), float(place.z)) + origin_offset
		var at := map_point(world)
		# A place on another storey is faded. On a section map it is left off only when its own
		# polygon lies over the storey on screen. A room that does not cover this page stays listed.
		var storey := _storey_at(world)
		var off_storey: bool = viewed >= 0 and storey >= 0 and storey != viewed
		if section_hi > 0 and off_storey and _overlaps_storey(world, storey, viewed): continue
		if str(place.get("kind", "place")) == "exit":
			shown_exits.append(str(place.id))
			var color := Color(EXIT_COLOR, 0.45) if off_storey else EXIT_COLOR
			# A marked gap: a short bar across the way out and the destination's name.
			draw_line(at + Vector2(-7, 0), at + Vector2(7, 0), color, 3.0, true)
			draw_line(at, at + Vector2(0, -9), color, 2.0, true)
			_place_label(font, at + Vector2(9, -4), str(place.name), color)
		else:
			shown_places.append(str(place.id))
			var color := Color(PLACE_COLOR, 0.45) if off_storey else PLACE_COLOR
			var diamond := PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 0), at + Vector2(0, 5), at + Vector2(-5, 0)])
			draw_colored_polygon(diamond, color)
			_place_label(font, at + Vector2(8, 4), str(place.name), color)
	var quests := _plot_state()
	var shown_plot: Array = []
	for marker in Places.active_plot(slice_area, _notes(), quests):
		# The marker sits at its place (on the border when the place is off the map); the place's own label names it when
		# that place is shown, otherwise the place name goes beside the marker. The full note is in the legend list.
		if section_hi > 0 and viewed >= 0:
			var marker_world := Vector2(float(marker.x), float(marker.z)) + origin_offset
			var marker_storey := _storey_at(marker_world)
			if marker_storey >= 0 and marker_storey != viewed and _overlaps_storey(marker_world, marker_storey, viewed): continue
		shown_plot.append(str(marker.note))
		var raw := map_point(Vector2(float(marker.x), float(marker.z)) + origin_offset)
		var at := _inside_map(raw)
		draw_circle(at, 6.0, PLOT_COLOR)
		draw_circle(at, 6.0, Color.BLACK, false, 1.0, true)
		if at != raw:
			# Off the map: a short pointer toward the real position.
			draw_line(at, at + (raw - at).normalized() * 10.0, PLOT_COLOR, 2.0, true)
		var place_id := str(marker.place)
		if not (place_id in shown_places) and not (place_id in shown_exits):
			var place_name: String = str(Places.place(slice_area, place_id).get("name", ""))
			var label_at := at + Vector2(9, -8)
			if at.x > size.x * 0.6: label_at.x = at.x - 9.0 - font.get_string_size(place_name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
			_place_label(font, label_at, place_name, PLOT_COLOR)
	# North box (native +y is up on the map).
	_box(north_box)
	var corner := north_box.position + Vector2(15, 22)
	draw_line(corner + Vector2(0, 8), corner + Vector2(0, -8), WALL_COLOR, 2.0, true)
	draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -12), corner + Vector2(-4, -4), corner + Vector2(4, -4)]), WALL_COLOR)
	_label(font, corner + Vector2(-4, 22), "N", WALL_COLOR)
	# Legend box.
	_box(legend)
	var base := legend.position + Vector2(8, 16)
	draw_line(base + Vector2(0, 0), base + Vector2(14, 0), WALL_COLOR, 2.0, true)
	_label(font, base + Vector2(20, 4), "wall  ·  gaps are open ways", WALL_COLOR)
	base.y += LABEL_SIZE + 3
	draw_colored_polygon(PackedVector2Array([base + Vector2(7, -5), base + Vector2(12, 0), base + Vector2(7, 5), base + Vector2(2, 0)]), PLACE_COLOR)
	_label(font, base + Vector2(20, 4), "place", PLACE_COLOR)
	base.y += LABEL_SIZE + 3
	draw_line(base + Vector2(0, 0), base + Vector2(14, 0), EXIT_COLOR, 3.0, true)
	_label(font, base + Vector2(20, 4), "way to another area", EXIT_COLOR)
	base.y += LABEL_SIZE + 3
	draw_circle(base + Vector2(7, 0), 5.0, PLOT_COLOR)
	_label(font, base + Vector2(20, 4), "what I have heard of  ·  gold: me", PLOT_COLOR)
	var listed := 0
	for text in _legend_rows():
		if listed >= 4: break
		base.y += LABEL_SIZE + 3
		draw_circle(base + Vector2(7, 0), 3.0, PLOT_COLOR)
		_label(font, base + Vector2(20, 4), str(text), PLOT_COLOR)
		listed += 1
	last_report = {"places": shown_places, "exits": shown_exits, "plot": shown_plot, "walls": drawn_walls, "explored": explored.size(), "filtering": filtering, "here": here, "blocked": blocked.size()}

func _box(rect: Rect2) -> void:
	draw_rect(rect, Color(0.07, 0.09, 0.1, 0.92))
	draw_rect(rect, WALL_FADE, false, 1.0)

func _label(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, 3, Color(0, 0, 0, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)

func zoom_at(factor: float, anchor: Vector2) -> void:
	var next_zoom := clampf(zoom * factor, 1.0, MAX_ZOOM)
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

## Storeys of a level's nav regions. Linked neighbours whose floors differ by at most STOREY_STEP (a ramp) form one
## component, unless that link would put two overlapping rooms more than STOREY_STEP apart in the same component.
## Those two are a pile (the catacomb hall under the cemetery), so each floor keeps its own storey. Components then
## merge into one storey unless a region of one lies over a region of the other, so a storey is a pile level, not a
## connectivity fragment (BJ05 2026-11-08: the Claw Mountains gulch walk fell into 6 of 551 fragments and the Atlas
## hid 60 of its 66 explored regions). Storeys rank by their median floor; rows are [{region, storey}] with -1 for
## a polygon-less region.
static func group_storeys(regions: Array) -> Array:
	var count := regions.size()
	var parent: Array = []
	parent.resize(count)
	var floors: Array = []
	floors.resize(count)
	var empty: Array = []
	empty.resize(count)
	var bounds: Array = []
	bounds.resize(count)
	var polygons: Array = []
	polygons.resize(count)
	for index in count:
		parent[index] = index
		var row: Array = regions[index]
		var polygon: Array = row[0]
		floors[index] = float(row[1])
		empty[index] = polygon.is_empty()
		if empty[index]: continue
		var packed := PackedVector2Array()
		for point in polygon: packed.append(Vector2(float(point[0]), float(point[1])))
		polygons[index] = packed
		var rect := Rect2(packed[0], Vector2.ZERO)
		for vertex in packed: rect = rect.expand(vertex)
		bounds[index] = rect
	var comp_ids: Array = []
	var comp_lo: Array = []
	var comp_hi: Array = []
	var comp_grid: Array = []
	comp_ids.resize(count)
	comp_lo.resize(count)
	comp_hi.resize(count)
	comp_grid.resize(count)
	for index in count:
		comp_ids[index] = [index]
		comp_lo[index] = float(floors[index])
		comp_hi[index] = float(floors[index])
		var grid: Dictionary = {}
		if not empty[index]:
			_grid_insert(grid, index, bounds[index])
		comp_grid[index] = grid
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
			if absf(floor - float(regions[other][1])) > STOREY_STEP: continue
			var left := _find_root(parent, index)
			var right := _find_root(parent, other)
			if left == right: continue
			var span := maxf(float(comp_hi[left]), float(comp_hi[right])) - minf(float(comp_lo[left]), float(comp_lo[right]))
			if span > STOREY_STEP:
				var small := left if (comp_ids[left] as Array).size() <= (comp_ids[right] as Array).size() else right
				var large := right if small == left else left
				var ids: Array = comp_ids[small]
				if _piled(ids, {"grid": comp_grid[large]}, floors, bounds, polygons):
					continue
			var keep := left
			var drop := right
			if (comp_ids[left] as Array).size() < (comp_ids[right] as Array).size():
				keep = right
				drop = left
			_union(parent, keep, drop)
			comp_lo[keep] = minf(float(comp_lo[keep]), float(comp_lo[drop]))
			comp_hi[keep] = maxf(float(comp_hi[keep]), float(comp_hi[drop]))
			var into: Array = comp_ids[keep]
			var kept_grid: Dictionary = comp_grid[keep]
			for id in comp_ids[drop]:
				var member := int(id)
				into.append(member)
				if not empty[member]:
					_grid_insert(kept_grid, member, bounds[member])
			comp_ids[drop] = []
			comp_grid[drop] = {}
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
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.median), float(b.median)): return float(a.median) < float(b.median)
		return int(a.min_id) < int(b.min_id))
	# Components join the storey nearest in height that they do not lie over; the first component opens the first storey.
	var storeys: Array = []
	for item in ordered:
		var candidates: Array = range(storeys.size())
		candidates.sort_custom(func(a: int, b: int) -> bool:
			var da := absf(float(storeys[a].median) - float(item.median))
			var db := absf(float(storeys[b].median) - float(item.median))
			if not is_equal_approx(da, db): return da < db
			return a < b)
		var joined := -1
		for candidate in candidates:
			if not _piled(item.ids, storeys[candidate], floors, bounds, polygons):
				joined = int(candidate)
				break
		if joined < 0:
			storeys.append({"ids": [], "grid": {}, "floors": [], "median": float(item.median), "min_id": int(item.min_id)})
			joined = storeys.size() - 1
		var storey: Dictionary = storeys[joined]
		for id in item.ids:
			storey.ids.append(id)
			storey.floors.append(floors[id])
			var rect: Rect2 = bounds[id]
			for gx in range(int(floor(rect.position.x / SECTION_CELL)), int(floor(rect.end.x / SECTION_CELL)) + 1):
				for gy in range(int(floor(rect.position.y / SECTION_CELL)), int(floor(rect.end.y / SECTION_CELL)) + 1):
					var cell := Vector2i(gx, gy)
					if not storey.grid.has(cell): storey.grid[cell] = []
					storey.grid[cell].append(id)
		storey.median = _median(storey.floors)
		storey.min_id = mini(int(storey.min_id), int(item.min_id))
	storeys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.median), float(b.median)): return float(a.median) < float(b.median)
		return int(a.min_id) < int(b.min_id))
	var storey_at: Dictionary = {}
	for number in storeys.size():
		for region in storeys[number].ids:
			storey_at[region] = number
	var rows: Array = []
	for index in count:
		rows.append({"region": index, "storey": -1 if empty[index] else int(storey_at[index])})
	return rows

static func _grid_insert(grid: Dictionary, id: int, rect: Rect2) -> void:
	var x0 := int(floor(rect.position.x / SECTION_CELL))
	var x1 := int(floor(rect.end.x / SECTION_CELL))
	var y0 := int(floor(rect.position.y / SECTION_CELL))
	var y1 := int(floor(rect.end.y / SECTION_CELL))
	for gx in range(x0, x1 + 1):
		for gy in range(y0, y1 + 1):
			var cell := Vector2i(gx, gy)
			if not grid.has(cell):
				grid[cell] = []
			(grid[cell] as Array).append(id)

## True when a region of `ids` lies over or under a region already in `storey`: their xz polygons overlap and their
## floors differ by more than the ramp step.
static func _piled(ids: Array, storey: Dictionary, floors: Array, bounds: Array, polygons: Array) -> bool:
	for id in ids:
		var rect: Rect2 = bounds[id]
		var seen: Dictionary = {}
		for gx in range(int(floor(rect.position.x / SECTION_CELL)), int(floor(rect.end.x / SECTION_CELL)) + 1):
			for gy in range(int(floor(rect.position.y / SECTION_CELL)), int(floor(rect.end.y / SECTION_CELL)) + 1):
				for other in storey.grid.get(Vector2i(gx, gy), []):
					if seen.has(other): continue
					seen[other] = true
					if absf(float(floors[id]) - float(floors[other])) <= STOREY_STEP: continue
					if not rect.intersects(bounds[other]): continue
					if _polygons_overlap(polygons[id], polygons[other]): return true
	return false

## Convex polygon overlap by separating axes (nav regions are quads); shared edges and corners do not count.
static func _polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for polygon in [a, b]:
		for i in polygon.size():
			var edge: Vector2 = polygon[(i + 1) % polygon.size()] - polygon[i]
			var axis := Vector2(-edge.y, edge.x)
			if axis.length_squared() < 0.000001: continue
			var a_lo := INF
			var a_hi := -INF
			for vertex in a:
				var projected := axis.dot(vertex)
				a_lo = minf(a_lo, projected)
				a_hi = maxf(a_hi, projected)
			var b_lo := INF
			var b_hi := -INF
			for vertex in b:
				var projected := axis.dot(vertex)
				b_lo = minf(b_lo, projected)
				b_hi = maxf(b_hi, projected)
			var tolerance := axis.length() * 0.5
			if a_hi <= b_lo + tolerance or b_hi <= a_lo + tolerance: return false
	return true

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
	blocked = {}
	if slice_area != "":
		var blockers_path := "res://assets/lol2/generated/region_blockers/%s.json" % slice_area
		if FileAccess.file_exists(blockers_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(blockers_path))
			if parsed is Dictionary and parsed.get("blocked_regions") is Array:
				for raw in parsed.blocked_regions: blocked[int(raw)] = true
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
		slices.append({"polygon": polygon, "can_fill": not Geometry2D.triangulate_polygon(polygon).is_empty(), "region": index, "storey": storey, "floor": float(row[1]), "walls": wall_sides(row, blocked), "blocked": blocked.has(index)})
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
