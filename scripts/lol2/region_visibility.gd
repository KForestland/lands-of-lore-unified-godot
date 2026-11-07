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
const NAV := "res://assets/lol2/generated/creature_nav/%s.json"
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
var last_pose := Transform3D()
var frames := 0

static func load_regions(area: String) -> Array:
	var path := NAV % area
	if not FileAccess.file_exists(path): return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data.regions if data is Dictionary and data.has("regions") else []

## Contiguous clusters of up to CLUSTER_SIZE regions (breadth-first over neighbours), region index -> cluster id.
static func clusters(nav: Array) -> Dictionary:
	var out: Dictionary = {}
	var next_id := 0
	for seed in nav.size():
		if out.has(seed): continue
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

func setup(owner_host: Node3D, area: String, nav: Array, cluster_map: Dictionary, meshes: Dictionary) -> void:
	host = owner_host; regions = nav; cluster_of = cluster_map; cluster_meshes = meshes
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

func _region_of(point: Vector3) -> int:
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
	var start := _region_of(pos)
	if start < 0: return {}
	var window: Dictionary = {start: Vector2(-half, half)}
	var queue: Array = [start]
	seen[start] = true
	var steps := 0
	while not queue.is_empty() and steps < MAX_STEPS:
		var r: int = queue.pop_front(); steps += 1
		var w: Vector2 = window[r]
		for e in edges[r]:
			var n: int = e[0]
			var a: Vector2 = e[1]; var b: Vector2 = e[2]
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
			if is_instance_valid(m): m.visible = on

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
