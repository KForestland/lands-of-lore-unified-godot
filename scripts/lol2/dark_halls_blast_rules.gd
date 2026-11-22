extends RefCounted
## Form101 / SPELL.ODF Explosion selector2: staged original radius, flags and integer falloff.
## Distances use the existing initialized-x87 adapter; this is not a live guest replay.
const SOURCE := "res://scripts/lol2/dark_halls_blast_source.json"
const Distance = preload("res://scripts/lol2/hive_condition_geometry.gd")

static func eligible(flags: int, kind: int) -> bool:
	return (flags & 0x4000) != 0 and kind != 4 and kind != 5

static func damage_fixed(distance: int, source: Dictionary) -> int:
	var radius: int = int(source.radius)
	if distance < 0 or distance >= radius << 16: return 0
	return ((((radius << 16) - distance) >> 16) * int(source.damage_factor)) / (radius + 1)

static func distance_fixed(a: Vector2, b: Vector2) -> int:
	var result: Dictionary = Distance.distance_between_startup([int(round(a.x * 65536)), int(round(a.y * 65536))], [int(round(b.x * 65536)), int(round(b.y * 65536))])
	return -1 if result.get("integer_invalid", false) else int(result.distance)

static func damage(a: Vector3, b: Vector3, source: Dictionary) -> int:
	return damage_fixed(distance_fixed(Vector2(a.x, a.z), Vector2(b.x, b.z)), source)

## B23BC expands through both edges meeting each nearby vertex (2R), ignoring blockers/wall flags.
static func candidate_regions(source: Dictionary, start: int, origin: Vector2) -> Array[int]:
	var queue: Array[int] = []
	if not source.regions.has(str(start)): return queue
	queue.append(start)
	var seen: Dictionary = {start: true}
	var cursor := 0
	var twice_radius: int = int(source.radius) * 2 << 16
	while cursor < queue.size() and queue.size() < int(source.native_region_cap):
		var row: Dictionary = source.regions[str(queue[cursor])]
		cursor += 1
		for k in 4:
			var vertex := Vector2(float(row.vertices[k][0]) / 65536.0, -float(row.vertices[k][1]) / 65536.0)
			if distance_fixed(origin, vertex) > twice_radius: continue
			for edge in [k, (k + 3) % 4]:
				var next: int = int(row.neighbors[edge])
				if next == 65535 or seen.has(next) or not source.regions.has(str(next)): continue
				seen[next] = true
				queue.append(next)
				if queue.size() >= int(source.native_region_cap): return queue
	return queue

## Current horizontal placement and nearest source floor select stacked regions.
## This lookup is the port binding; B23BC's expansion above remains the decoded topology rule.
static func region_at(source: Dictionary, point: Vector3) -> int:
	var best := -1
	var distance := INF
	for key in source.regions:
		var row: Dictionary = source.regions[key]
		var polygon := PackedVector2Array()
		for vertex in row.vertices:
			polygon.append(Vector2(float(vertex[0]) / 65536.0, -float(vertex[1]) / 65536.0))
		if not Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon): continue
		var floor_y := 0.0
		for y in row.floor: floor_y += float(y) / float(row.floor.size())
		var dy := absf(point.y - floor_y)
		if dy < distance:
			distance = dy
			best = int(key)
	return best
