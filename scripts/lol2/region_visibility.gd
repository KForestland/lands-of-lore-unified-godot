extends Node
## Portal visibility for the Act 2/3 map hosts (owner 2026-11-05: "the temple is a huge mess since the clipping and
## portals inside"; longplay g_276/g_278: platforms in a black void). The original 2.5D engine draws only the regions it
## reaches through region edges (portals) inside the view; rooms that overlap or lie beyond solid walls are never drawn.
## The port drew every face of the level, so other rooms showed through the open sky and clipped into view.
## Method (modern adapter, DEVIATIONS 2026-11-05): regions are grouped into small contiguous clusters (static meshes are
## batched per cluster by jungle_review.gd); each frame a breadth-first walk starts in the camera's region with the
## horizontal view window and passes a shared region edge only where that edge lies inside the current window, narrowing
## the window to the edge (Build-engine style). Regions within NEAR units of the camera are always drawn (no popping at
## doorways). Clusters with no reached region are hidden. Collision is untouched; only drawing changes.
## Visibility islands (Fable TEMPLE-ISLANDS 2026-11-07, L14 first): the map pack names the original's room of every static face
## (render_sector). With islands(nav, faces) the batching unit is that room instead of a 24-region cluster, and setup(...,
## faces) lets the walk leave a room only through an opening: a shared region edge whose floor/ceiling spans overlap by
## OPENING units after the wall faces drawn on that edge are subtracted. Stacked rooms (a floor-0 hall above a -80 room)
## share no opening, so they are never drawn together; a doorway, a window or a parapet still is one. Collision untouched.
## The native potential set (scripts/lol2/sector_potential/<area>.json, tools/prepare_sector_potential.py: the sectors each
## sector's portal edges name in the archive, the original renderer's conservative draw membership) bounds the walk: a room
## outside the camera room's set is never drawn, whatever the window walk reaches.
const NAV := "res://assets/lol2/generated/creature_nav/%s.json"
const POTENTIAL := "res://scripts/lol2/sector_potential/%s.json"
const OPENING := 24.0
const CLUSTER_SIZE := 24
const NEAR := 160.0
const MAX_STEPS := 6000
const MARGIN := 0.35  # radians added to the horizontal half field of view
var host: Node3D
var regions: Array = []
var edges: Array = []          # region -> [[neighbor, Vector2 a, Vector2 b], ...]
var cluster_of: Dictionary = {}
var cluster_meshes: Dictionary = {}
var visible_regions: Dictionary = {}
var enabled := true
var closed_edges := 0   # edges between two islands that are not an opening (islands mode only)
var potential: Dictionary = {}   # island -> Dictionary set of islands the original may draw from it (islands mode only)
var bounded := 0   # regions the native potential set kept out of the last walk
var last_start := -1   # the region the last walk started from
## Seed radius (Fable MAPFIX 2026-11-07, Hive first): every region whose polygon lies within this distance of the camera
## (and within 700 units of its height) starts the walk with the full window, as the camera's own region does. The deep
## Hive hall is a chasm: the platform the player stands on shares no region edge with the hall around it, so the walk
## stopped at once and the hall's walls appeared only after a step onto a connected region (owner r17 17-28-43/17-29-06).
## 0 keeps the single start region.
var seed_radius := 0.0
var seeded := 0
var last_pose := Transform3D()
## G-14 (owner report 06-24-24, black doorway): two regions that meet on a split (T-junction) edge share no identical
## endpoints, so the walk never crossed into the room behind (L14 region 1063). With overlap_edges, polygon edges that lie
## on one line and overlap are portals too, over their common segment; the walls of both original edges still close it.
var overlap_edges := true
var overlap_joined := 0
const OVERLAP_TOLERANCE := 1.0
var overlap_wall_keys: Dictionary = {}   # "r|n|segment key" -> [edge key of r, edge key of n] for the wall subtraction
var frames := 0

static func load_regions(area: String) -> Array:
	var path: String = preload("res://scripts/lol2/geometry_move.gd").nav_path(area, NAV % area)
	if not FileAccess.file_exists(path): return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data.regions if data is Dictionary and data.has("regions") else []

## Contiguous clusters of up to CLUSTER_SIZE regions (breadth-first over neighbours), region index -> cluster id.
static func clusters(nav: Array) -> Dictionary:
	var out: Dictionary = {}
	var next_id := 0
	for seed in nav.size():
		if out.has(seed): continue
		# A region without a polygon (the producer's floor subdivisions: stair steps, 28 in L10, 283 in the Hive) has no
		# edges, so a cluster of its own would never be reached and its floor strip never drawn (owner r17 17-55-17: the
		# sky's nadir fan through the missing step under the player). It stays out of the clusters and is always drawn.
		if (nav[seed][0] as Array).is_empty(): continue
		var queue: Array = [seed]; var count := 0
		out[seed] = next_id
		while not queue.is_empty() and count < CLUSTER_SIZE:
			var r: int = queue.pop_front(); count += 1
			for e in nav[r][3]:
				var n := int(e[0])
				if n < nav.size() and not out.has(n) and count + queue.size() < CLUSTER_SIZE:
					out[n] = next_id; queue.append(n)
		next_id += 1
	return out

## The staged native room data of an area (tools/prepare_sector_potential.py), or {} when none is staged.
static func load_native(area: String) -> Dictionary:
	var path := POTENTIAL % area
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

## The native potential sets of an area as island -> {island: true}, or {} when the area has none staged.
static func load_potential(area: String) -> Dictionary:
	var data: Dictionary = load_native(area)
	if not (data.get("potential") is Dictionary): return {}
	var out: Dictionary = {}
	for key in data.potential:
		var set: Dictionary = {}
		for other in data.potential[key]: set[int(other)] = true
		out[int(key)] = set
	return out

## Region index -> the original's room (render_sector of its faces). Regions without a static face keep -1 (never batched).
static func islands(nav: Array, faces: Array) -> Dictionary:
	var out: Dictionary = {}
	for face in faces:
		if not (face is Dictionary): continue
		var region: Variant = face.get("region")
		if region == null or int(region) < 0 or int(region) >= nav.size(): continue
		var sector := int(face.get("render_sector", -1))
		if sector < 0: continue
		out[int(region)] = sector
	return out

static func _edge_key(a: Vector2, b: Vector2) -> String:
	var ka := "%d,%d" % [roundi(a.x), roundi(a.y)]; var kb := "%d,%d" % [roundi(b.x), roundi(b.y)]
	return ka + "|" + kb if ka < kb else kb + "|" + ka

## Length of [lo, hi] not covered by the wall spans [[lo, hi], ...] drawn on an edge.
static func uncovered(lo: float, hi: float, spans: Array) -> float:
	var segments: Array = [Vector2(lo, hi)]
	for span in spans:
		var next: Array = []
		for seg in segments:
			var s: Vector2 = seg
			if span.y <= s.x or span.x >= s.y: next.append(s); continue
			if span.x > s.x: next.append(Vector2(s.x, span.x))
			if span.y < s.y: next.append(Vector2(span.y, s.y))
		segments = next
	var total := 0.0
	for seg in segments: total += (seg as Vector2).y - (seg as Vector2).x
	return total

var surface_floors: Dictionary = {}
var surface_ceilings: Dictionary = {}
var surface_walls: Dictionary = {}
var surface_source_walls: Dictionary = {}   # the original's own wall records (kind source_wall): overlap joins only

## Floors/ceilings per region and wall spans per exact edge key, from the pack faces (used by the opening checks).
func _index_surfaces(faces: Array) -> void:
	var floors: Dictionary = {}; var ceilings: Dictionary = {}; var walls: Dictionary = {}; var source_walls: Dictionary = {}
	for face in faces:
		if not (face is Dictionary) or not face.has("points"): continue
		var kind := str(face.get("kind", ""))
		var pts: Array = face.points
		if pts.is_empty(): continue
		var lo := INF; var hi := -INF
		for p in pts: lo = minf(lo, float(p[1])); hi = maxf(hi, float(p[1]))
		var region: Variant = face.get("region")
		if kind == "floor" and region != null:
			floors[int(region)] = minf(float(floors.get(int(region), INF)), lo)
		elif kind == "ceiling" and region != null:
			ceilings[int(region)] = maxf(float(ceilings.get(int(region), -INF)), hi)
		elif kind == "wall" or kind == "source_wall":
			var target: Dictionary = walls if kind == "wall" else source_walls
			var a := Vector2(float(pts[0][0]), float(pts[0][2])); var b := a
			for p in pts:
				var q := Vector2(float(p[0]), float(p[2]))
				if q.distance_to(a) > 0.5: b = q; break
			if b == a: continue
			var key := _edge_key(a, b)
			if not target.has(key): target[key] = []
			target[key].append(Vector2(lo, hi))
	surface_floors = floors; surface_ceilings = ceilings; surface_walls = walls; surface_source_walls = source_walls

## The open height between regions r and n across a segment whose walls are listed under wall_keys.
func _open_height(r: int, n: int, wall_keys: Array) -> float:
	var floor_r := float(surface_floors.get(r, float(regions[r][1]))); var floor_n := float(surface_floors.get(n, float(regions[n][1])))
	var ceil_r := float(surface_ceilings.get(r, INF)); var ceil_n := float(surface_ceilings.get(n, INF))
	var lo := maxf(floor_r, floor_n); var hi := minf(ceil_r, ceil_n)
	if hi == INF: hi = lo + 4096.0
	if hi - lo < OPENING: return 0.0
	var spans: Array = []
	for key in wall_keys:
		spans.append_array(surface_walls.get(key, []))
		spans.append_array(surface_source_walls.get(key, []))
	return uncovered(lo, hi, spans)

func _classify_openings(faces: Array) -> int:
	if surface_walls.is_empty() and surface_floors.is_empty(): _index_surfaces(faces)
	var floors: Dictionary = surface_floors; var ceilings: Dictionary = surface_ceilings; var walls: Dictionary = surface_walls
	var closed := 0
	for r in regions.size():
		var rows: Array = edges[r]
		for i in rows.size():
			var e: Array = rows[i]
			var n := int(e[0])
			if int(cluster_of.get(r, -1)) == int(cluster_of.get(n, -1)): continue
			var floor_r := float(floors.get(r, float(regions[r][1]))); var floor_n := float(floors.get(n, float(regions[n][1])))
			var ceil_r := float(ceilings.get(r, INF)); var ceil_n := float(ceilings.get(n, INF))
			var lo := maxf(floor_r, floor_n); var hi := minf(ceil_r, ceil_n)
			if hi == INF: hi = lo + 4096.0
			var spans: Array = walls.get(_edge_key(e[1], e[2]), []).duplicate()
			for wall_key in overlap_wall_keys.get("%d|%d|%s" % [r, n, _edge_key(e[1], e[2])], []): spans.append_array(walls.get(wall_key, []))
			var open := hi - lo >= OPENING and uncovered(lo, hi, spans) >= OPENING
			if not open: closed += 1
			e.append(open)
	return closed

func setup(owner_host: Node3D, area: String, nav: Array, cluster_map: Dictionary, meshes: Dictionary, faces: Array = [], potential_sets: Dictionary = {}, classify_islands: bool = true) -> void:
	host = owner_host; regions = nav; cluster_of = cluster_map; cluster_meshes = meshes; potential = potential_sets
	name = "RegionVisibility"
	process_priority = 100
	edges.resize(regions.size())
	for r in regions.size(): edges[r] = []
	# Every polygon edge two regions share is a portal for drawing, also where the creature graph has no link (low
	# walls, parapets, drops to a lower floor, windows: grok N01 review of 75597f2, longplay g_62/g_71/g_87/g_125).
	var by_edge: Dictionary = {}
	for r in regions.size():
		var poly: Array = regions[r][0]
		for i in poly.size():
			var a := Vector2(poly[i][0], poly[i][1]); var b := Vector2(poly[(i + 1) % poly.size()][0], poly[(i + 1) % poly.size()][1])
			if a.distance_to(b) < 0.5: continue
			var ka := "%d,%d" % [roundi(a.x), roundi(a.y)]; var kb := "%d,%d" % [roundi(b.x), roundi(b.y)]
			var key := ka + "|" + kb if ka < kb else kb + "|" + ka
			if not by_edge.has(key): by_edge[key] = []
			by_edge[key].append([r, a, b])
	for key in by_edge:
		var rows: Array = by_edge[key]
		for x in rows:
			for y in rows:
				if x[0] != y[0]: edges[x[0]].append([y[0], x[1], x[2]])
	if not faces.is_empty(): _index_surfaces(faces)
	# Islands levels only: there every cross-room edge is classified against its walls and the drawing unit is the room.
	# On cluster levels a join draws a whole 24-region cluster, which on L10 brought in the walled room 776 behind the yard.
	if overlap_edges and classify_islands: overlap_joined = _join_collinear_overlaps(by_edge)
	# Creature-graph links whose edges did not match exactly (split edges) are kept too.
	for r in regions.size():
		var known: Dictionary = {}
		for e in edges[r]: known[int(e[0])] = true
		for e in regions[r][3]:
			var n := int(e[0])
			if n >= regions.size() or known.has(n): continue
			var mid := Vector2(float(e[1]), float(e[2]))
			var poly: Array = regions[r][0]
			var best := -1; var best_d := 2.5
			for i in poly.size():
				var a := Vector2(poly[i][0], poly[i][1]); var b := Vector2(poly[(i + 1) % poly.size()][0], poly[(i + 1) % poly.size()][1])
				var d := ((a + b) * 0.5).distance_to(mid)
				if d < best_d: best_d = d; best = i
			if best >= 0:
				edges[r].append([n, Vector2(poly[best][0], poly[best][1]), Vector2(poly[(best + 1) % poly.size()][0], poly[(best + 1) % poly.size()][1])])
	if not faces.is_empty() and classify_islands: closed_edges = _classify_openings(faces)

## Joins region pairs whose polygon edges are collinear and overlap but do not match end to end. Returns the pair count.
func _join_collinear_overlaps(by_edge: Dictionary) -> int:
	var rows: Array = []   # [region, a, b, key]
	for key in by_edge:
		for row in by_edge[key]: rows.append([int(row[0]), row[1], row[2], key])
	const CELL := 128.0
	var grid: Dictionary = {}
	for i in rows.size():
		var a: Vector2 = rows[i][1]; var b: Vector2 = rows[i][2]
		for cx in range(floori(minf(a.x, b.x) / CELL), floori(maxf(a.x, b.x) / CELL) + 1):
			for cz in range(floori(minf(a.y, b.y) / CELL), floori(maxf(a.y, b.y) / CELL) + 1):
				var c := Vector2i(cx, cz)
				if not grid.has(c): grid[c] = []
				grid[c].append(i)
	var known: Dictionary = {}
	for r in regions.size():
		for e in edges[r]: known["%d|%d" % [r, int(e[0])]] = true
	var joined := 0
	var done: Dictionary = {}
	for c in grid:
		var ids: Array = grid[c]
		for x in ids:
			for y in ids:
				if x >= y: continue
				var pair := "%d|%d" % [x, y]
				if done.has(pair): continue
				done[pair] = true
				var rx: int = rows[x][0]; var ry: int = rows[y][0]
				if rx == ry or rows[x][3] == rows[y][3]: continue
				var a: Vector2 = rows[x][1]; var b: Vector2 = rows[x][2]
				var p: Vector2 = rows[y][1]; var q: Vector2 = rows[y][2]
				var length := a.distance_to(b)
				if length < 0.5: continue
				var dir := (b - a) / length
				var normal := Vector2(-dir.y, dir.x)
				if absf((p - a).dot(normal)) > OVERLAP_TOLERANCE or absf((q - a).dot(normal)) > OVERLAP_TOLERANCE: continue
				var t0 := maxf(0.0, minf((p - a).dot(dir), (q - a).dot(dir)))
				var t1 := minf(length, maxf((p - a).dot(dir), (q - a).dot(dir)))
				if t1 - t0 < OPENING: continue
				var sa := a + dir * t0; var sb := a + dir * t1
				var seg_key := _edge_key(sa, sb)
				# A wall standing on either original edge closes the overlap (L10 room 776 behind the yard fence, 2026-11-12):
				# the segment must keep OPENING units of height between both regions' floors and ceilings after the walls.
				if not surface_floors.is_empty() and _open_height(rx, ry, [rows[x][3], rows[y][3]]) < OPENING: continue
				if not known.has("%d|%d" % [rx, ry]):
					edges[rx].append([ry, sa, sb]); known["%d|%d" % [rx, ry]] = true; joined += 1
					overlap_wall_keys["%d|%d|%s" % [rx, ry, seg_key]] = [rows[x][3], rows[y][3]]
				if not known.has("%d|%d" % [ry, rx]):
					edges[ry].append([rx, sa, sb]); known["%d|%d" % [ry, rx]] = true
					overlap_wall_keys["%d|%d|%s" % [ry, rx, seg_key]] = [rows[y][3], rows[x][3]]
	return joined

static func region_at_nav(nav: Array, point: Vector3) -> int:
	var best := -1
	var best_dy := INF
	var flat := Vector2(point.x, point.z)
	for i in nav.size():
		var row: Array = nav[i]
		if row.is_empty() or not (row[0] is Array): continue
		var quad: Array = row[0]
		if quad.is_empty(): continue
		var poly := PackedVector2Array()
		for v in quad:
			poly.append(Vector2(float(v[0]), float(v[1])))
		if not Geometry2D.is_point_in_polygon(flat, poly): continue
		var dy := absf(point.y - float(row[1]))
		if dy < best_dy:
			best_dy = dy
			best = i
	return best

## Draw-only floor selection. L10 has overlapping cabinet/upper-storey cells;
## the script region's XY cache and nearest-camera-floor rule can name a floor
## above the body. Prefer its actual containing air band below the FEET.
static func floor_region(nav: Array, feet: Vector3, ceilings: Dictionary) -> int:
	var best := -1
	var highest := -INF
	var flat := Vector2(feet.x,feet.z)
	for i in nav.size():
		var row: Array = nav[i]
		if row.is_empty() or (row[0] as Array).is_empty(): continue
		var floor_height := float(row[1])
		if floor_height > feet.y + 1.0 or floor_height <= highest: continue
		if float(ceilings.get(i,INF)) <= feet.y + 1.0: continue
		var polygon := PackedVector2Array()
		for v: Array in row[0]: polygon.append(Vector2(v[0],v[1]))
		if Geometry2D.is_point_in_polygon(flat,polygon): best=i;highest=floor_height
	return best

func _region_of(point: Vector3) -> int:
	if str(host.get("area_id")) == "L10_DC" and is_instance_valid(host.get("player")):
		var feet: Vector3 = host.player.global_position - Vector3(0,preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,0)
		var physical := floor_region(regions,feet,surface_ceilings)
		if physical >= 0: return physical
	var p = host.get("progression")
	if p != null and p.has_method("region_at"): return int(p.region_at(point))
	var nav_at: Variant = host.get("portal_regions")
	if nav_at is Array and not (nav_at as Array).is_empty(): return region_at_nav(nav_at, point)
	return -1

func _angle(cam: Vector2, fwd: Vector2, right: Vector2, q: Vector2) -> Vector2:
	var d := q - cam
	return Vector2(d.dot(right), d.dot(fwd))  # x = sideways, y = depth

## Angular interval of segment a-b seen from the camera (camera space), or empty (x > y) when behind.
func _interval(cam: Vector2, fwd: Vector2, right: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var pa := _angle(cam, fwd, right, a); var pb := _angle(cam, fwd, right, b)
	const EPS := 0.5
	if pa.y < EPS and pb.y < EPS: return Vector2(1, -1)
	if pa.y < EPS: pa = pb + (pa - pb) * ((pb.y - EPS) / (pb.y - pa.y))
	elif pb.y < EPS: pb = pa + (pb - pa) * ((pa.y - EPS) / (pa.y - pb.y))
	var ta := atan2(pa.x, pa.y); var tb := atan2(pb.x, pb.y)
	return Vector2(minf(ta, tb), maxf(ta, tb))

func compute(camera: Camera3D) -> Dictionary:
	var seen: Dictionary = {}
	var pos := camera.global_position
	var cam := Vector2(pos.x, pos.z)
	var f3 := -camera.global_basis.z
	var fwd := Vector2(f3.x, f3.z)
	if fwd.length() < 0.01: fwd = Vector2(0, -1)
	fwd = fwd.normalized()
	var right := Vector2(-fwd.y, fwd.x)
	var aspect := 16.0 / 9.0
	var vp := camera.get_viewport()
	if vp != null:
		var size := vp.get_visible_rect().size
		if size.y > 0: aspect = size.x / size.y
	var half := atan(tan(deg_to_rad(camera.fov) * 0.5) * aspect) + MARGIN
	# G-05: start from the region the player is tracked in (act2_map tracker) while the camera stands in it.
	var start := -1
	if host != null and host.has_method("tracked_region_for"): start = int(host.tracked_region_for(pos))
	if start < 0: start = _region_of(pos)
	if start < 0: return {}
	last_start = start
	var own := int(cluster_of.get(start, -1))
	# With potential sets staged, a room with no named sector draws alone (bound_walk true, allowed empty).
	var bound_walk := not potential.is_empty() and own >= 0
	var allowed: Dictionary = potential.get(own, {}) if bound_walk else {}
	bounded = 0
	var window: Dictionary = {start: Vector2(-half, half)}
	var queue: Array = [start]
	seen[start] = true
	seeded = 0
	if seed_radius > 0.0:
		for r in regions.size():
			if window.has(r) or absf(float(regions[r][1]) - pos.y) > 700.0: continue
			var poly: Array = regions[r][0]
			var inside := false
			for i in poly.size():
				var a := Vector2(poly[i][0], poly[i][1]); var b := Vector2(poly[(i + 1) % poly.size()][0], poly[(i + 1) % poly.size()][1])
				if Geometry2D.get_closest_point_to_segment(cam, a, b).distance_to(cam) <= seed_radius: inside = true; break
			if not inside: continue
			window[r] = Vector2(-half, half); seen[r] = true; queue.append(r); seeded += 1
	var steps := 0
	while not queue.is_empty() and steps < MAX_STEPS:
		var r: int = queue.pop_front(); steps += 1
		var w: Vector2 = window[r]
		for e in edges[r]:
			var n: int = e[0]
			if e.size() > 3 and not bool(e[3]): continue
			var a: Vector2 = e[1]; var b: Vector2 = e[2]
			if bound_walk:
				var island := int(cluster_of.get(n, -1))
				if island != own and not allowed.has(island): bounded += 1; continue
			var near := Geometry2D.get_closest_point_to_segment(cam, a, b).distance_to(cam) < NEAR
			var iv := Vector2(-half, half) if near else _interval(cam, fwd, right, a, b)
			var lo := maxf(iv.x, w.x); var hi := minf(iv.y, w.y)
			if hi <= lo: continue
			var nw := Vector2(lo, hi)
			if window.has(n):
				var old: Vector2 = window[n]
				if nw.x >= old.x - 0.001 and nw.y <= old.y + 0.001: continue
				nw = Vector2(minf(old.x, nw.x), maxf(old.y, nw.y))
			window[n] = nw; seen[n] = true; queue.append(n)
	return seen

func apply(seen: Dictionary) -> void:
	visible_regions = seen
	var shown: Dictionary = {}
	for r in seen: shown[int(cluster_of.get(r, -1))] = true
	for c in cluster_meshes:
		var on := (not enabled) or shown.has(int(c))
		for m in cluster_meshes[c]:
			if not is_instance_valid(m): continue
			if not m.has_meta("object_rooms"): m.visible = on; continue
			# A generic front can border more than one actual room. Draw it
			# when ANY room its published faces touch is drawn, never last-writer wins.
			var object_on := not enabled
			for room in m.get_meta("object_rooms"):
				if shown.has(int(room)): object_on = true; break
			m.visible = object_on

func _process(_delta: float) -> void:
	if regions.is_empty() or host == null: return
	var camera: Camera3D = host.get("camera")
	if camera == null: return
	frames += 1
	var pose := camera.global_transform
	if frames > 2 and pose.origin.distance_to(last_pose.origin) < 2.0 and pose.basis.z.dot(last_pose.basis.z) > 0.9995: return
	last_pose = pose
	if not enabled: apply({}); return
	var seen := compute(camera)
	if seen.is_empty(): return
	apply(seen)
