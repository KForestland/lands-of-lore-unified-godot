extends RefCounted
## Region-edge rule for the Act 2/3 map packs (BK01/BK02, 2026-11-09). The original's movement is region-based: the player
## can leave a region only through a side that has a neighbour; a wall record between two linked regions is scenery, and a
## side with no neighbour is impassable whether or not a wall is drawn there. The packs carry both kinds of vertical face:
##   - "wall" faces built at a region side with no neighbour (boundary), always collidable so far. In L17 region 1236's
##     corridor overlaps corridor 562 at the same floor (two region layouts in one space); 1236's no-neighbour side is a
##     wall built straight across 562 (the cave throat at (-4616, -2094)): a player walking 562's graph never meets it
##     in the original.
##   - "source_wall" faces (the original's own wall records), drawn but never collidable. The L19 blood pool is a hole in
##     the region graph; its rim walls are source walls, so the port lets the player walk off the rim into the void.
## This rule classifies each vertical face by what lies just beyond it in the nav (creature_nav/<AREA>.json polygons):
##   pass  - a nav polygon with a floor within STEP of the face's base lies beyond: the face does not block (and a built
##           boundary "wall" there is not drawn either, as the original's portal renderer would not draw it);
##   block - no walkable region lies beyond: the face blocks, even a source wall.
## Faces whose owning region has no nav polygon, or whose horizontal extent is not a single segment, keep the old behaviour.
const STEP := 48.0
const CELL := 256.0
const PROBE := 10.0

## The owning region of a pack face, -1 when the pack stores none (null) or a non-number.
static func face_region(face: Dictionary) -> int:
	var value: Variant = face.get("region", -1)
	return int(value) if (value is int or value is float) else -1

static func face_key(face: Dictionary) -> String:
	var ends: Array = _ends(face)
	if ends.is_empty(): return ""
	var lo := INF
	var hi := -INF
	for p in face.points:
		lo = minf(lo, float(p[1]))
		hi = maxf(hi, float(p[1]))
	return "%s|%d,%d|%d,%d|%d|%d" % [str(face.get("kind", "")), roundi(ends[0].x), roundi(ends[0].y), roundi(ends[1].x), roundi(ends[1].y), roundi(lo), roundi(hi)]

## The two distinct x/z positions of a vertical quad, or [] when it is not a single vertical segment.
static func _ends(face: Dictionary) -> Array:
	var found: Array = []
	for p in face.points:
		var q := Vector2(float(p[0]), float(p[2]))
		var seen := false
		for f in found:
			if f.distance_to(q) < 1.0: seen = true; break
		if not seen: found.append(q)
	return found if found.size() == 2 else []

## {"pass": {index: true}, "block": {face_key: true}, "counts": {...}} for the pack's vertical faces.
static func classify(faces: Array, regions: Array) -> Dictionary:
	var grid: Dictionary = {}
	var polygons: Array = []
	var centroids: Dictionary = {}
	polygons.resize(regions.size())
	for index in regions.size():
		var row: Array = regions[index]
		var source: Array = row[0]
		if source.is_empty(): continue
		var polygon := PackedVector2Array()
		var total := Vector2.ZERO
		for p in source:
			var v := Vector2(float(p[0]), float(p[1]))
			polygon.append(v)
			total += v
		polygons[index] = polygon
		centroids[index] = total / float(polygon.size())
		var box := Rect2(polygon[0], Vector2.ZERO)
		for v in polygon: box = box.expand(v)
		for gx in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
			for gz in range(floori(box.position.y / CELL), floori(box.end.y / CELL) + 1):
				var cell := Vector2i(gx, gz)
				if not grid.has(cell): grid[cell] = []
				grid[cell].append(index)
	var pass_faces: Dictionary = {}
	var block_keys: Dictionary = {}
	var counts := {"walls": 0, "source_walls": 0, "pass_walls": 0, "block_source_walls": 0, "unclassified": 0}
	for index in faces.size():
		var face: Dictionary = faces[index]
		var kind := str(face.get("kind", ""))
		if kind != "wall" and kind != "source_wall": continue
		if kind == "wall": counts.walls += 1
		else: counts.source_walls += 1
		var region := face_region(face)
		var ends: Array = _ends(face)
		if ends.is_empty() or region < 0 or region >= regions.size() or not centroids.has(region):
			counts.unclassified += 1
			continue
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		var normal := Vector2(-along.y, along.x)
		var centroid: Vector2 = centroids[region]
		if normal.dot(centroid - mid) > 0.0: normal = -normal   # outward: away from the owning region
		var probe := mid + normal * PROBE
		var base := INF
		for p in face.points: base = minf(base, float(p[1]))
		var beyond := false
		var cell := Vector2i(floori(probe.x / CELL), floori(probe.y / CELL))
		for other in grid.get(cell, []):
			var other_index := int(other)
			if other_index == region: continue
			if absf(float(regions[other_index][1]) - base) > STEP: continue
			if Geometry2D.is_point_in_polygon(probe, polygons[other_index]):
				beyond = true
				break
		if kind == "wall" and beyond:
			pass_faces[index] = true
			counts.pass_walls += 1
		elif kind == "source_wall" and not beyond:
			block_keys[face_key(face)] = true
			counts.block_source_walls += 1
	return {"pass": pass_faces, "block": block_keys, "counts": counts}

## Walkable adjacency of the nav for the region-aware collision (act2_map): region -> {neighbour: true} from the stored edges
## within STEP plus polygon sides shared with another region within STEP (two layouts that merely cross share no side).
static func links(regions: Array) -> Dictionary:
	var out: Dictionary = {}
	var polygons: Array = []
	var boxes: Array = []
	var grid: Dictionary = {}
	polygons.resize(regions.size())
	boxes.resize(regions.size())
	for index in regions.size():
		out[index] = {}
		var row: Array = regions[index]
		if (row[0] as Array).is_empty(): continue
		var polygon := PackedVector2Array()
		for p in row[0]: polygon.append(Vector2(float(p[0]), float(p[1])))
		polygons[index] = polygon
		var box := Rect2(polygon[0], Vector2.ZERO)
		for v in polygon: box = box.expand(v)
		boxes[index] = box
		for gx in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
			for gz in range(floori(box.position.y / CELL), floori(box.end.y / CELL) + 1):
				var cell := Vector2i(gx, gz)
				if not grid.has(cell): grid[cell] = []
				grid[cell].append(index)
		for edge in row[3]:
			if not edge is Array or edge.is_empty(): continue
			var other := int(edge[0])
			if other < 0 or other >= regions.size() or (regions[other][0] as Array).is_empty(): continue
			if absf(float(row[1]) - float(regions[other][1])) > STEP: continue
			out[index][other] = true
	var seen: Dictionary = {}
	for cell in grid:
		var ids: Array = grid[cell]
		for x in ids.size():
			for y in range(x + 1, ids.size()):
				var i: int = ids[x]
				var j: int = ids[y]
				var pair := Vector2i(mini(i, j), maxi(i, j))
				if seen.has(pair): continue
				seen[pair] = true
				if out[i].has(j): continue
				if absf(float(regions[i][1]) - float(regions[j][1])) > STEP: continue
				var bi: Rect2 = boxes[i]
				var bj: Rect2 = boxes[j]
				if not bi.grow(2.0).intersects(bj): continue
				if _share_side(polygons[i], polygons[j]):
					out[i][j] = true
					out[j][i] = true
	return out

## True when a side of `a` and a side of `b` lie on one line and overlap by 8 units or more.
static func _share_side(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for i in a.size():
		var a1: Vector2 = a[i]
		var a2: Vector2 = a[(i + 1) % a.size()]
		var along := a2 - a1
		var length := along.length()
		if length < 0.001: continue
		var u := along / length
		for j in b.size():
			var b1: Vector2 = b[j]
			var b2: Vector2 = b[(j + 1) % b.size()]
			var d1: float = absf((b1 - a1).cross(u))
			var d2: float = absf((b2 - a1).cross(u))
			if d1 > 2.0 or d2 > 2.0: continue
			var t1: float = (b1 - a1).dot(u)
			var t2: float = (b2 - a1).dot(u)
			var lo: float = maxf(0.0, minf(t1, t2))
			var hi: float = minf(length, maxf(t1, t2))
			if hi - lo >= 8.0: return true
	return false
