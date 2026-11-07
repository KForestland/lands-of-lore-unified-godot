extends Node3D
## Draw-only water on Jungle banks the span builder left open (owner r16 F10).
## Region 2559 at (-4603,-3412): bed -20, surface -5, no wall on the bank, so the backdrop shows
## through the channel and no water is drawn. Region 260 at (-3408,-4454): bed -20, surface -15,
## one edge walled; from under the sheet the sides are open. Native outer walls exist only where
## neighbors is null. A same-bed neighbour (floors within 30) keeps the pool open above the bed.
## The drowning column already reaches 64 under the bed, and that is the span the underwater camera
## looks through, so unwalled edges also get a skirt down to floor-64. Material 808. No collision.
const EDGE_DIST := 16.0
const UNDER_BED := 64.0

func build(host: Node3D) -> int:
	var liquid = host.get("liquid_drowning")
	if liquid == null or not is_instance_valid(liquid): return 0
	var regions: Array = liquid.regions
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(host.geometry_file)))
	var planned: Array = plan(regions, data.faces)
	if planned.is_empty(): return 0
	var source: Material = host.materials.get("808")
	var mat := StandardMaterial3D.new()
	if source is StandardMaterial3D:
		mat = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var by_region: Dictionary = {}
	for item in planned:
		var quad: Dictionary = item
		var id := int(quad.region)
		if not by_region.has(id): by_region[id] = []
		(by_region[id] as Array).append(quad)
	var count := 0
	for id in by_region:
		var mesh := MeshInstance3D.new()
		mesh.name = "WaterSkirt%s" % str(id)
		mesh.mesh = _mesh(by_region[id], mat)
		add_child(mesh)
		var cluster := int(host.region_cluster.get(int(id), -1))
		if cluster >= 0:
			if not host.cluster_meshes.has(cluster): host.cluster_meshes[cluster] = []
			(host.cluster_meshes[cluster] as Array).append(mesh)
		count += 1
	return count

## Quads for tests and build: {region, kind, points:[Vector3, Vector3, Vector3]}.
static func plan(regions: Array, faces: Array) -> Array:
	var walls := _index_walls(faces)
	var shared := _shared_edges(regions)
	var out: Array = []
	for item in regions:
		var region: Dictionary = item
		if float(region.surface) <= float(region.floor) + 1.0: continue
		var poly: Array = _poly(region.polygon)
		var id := _region_id(region)
		var floor_y := float(region.floor)
		var surface_y := float(region.surface)
		if poly.size() >= 3:
			var origin := Vector3(poly[0].x, surface_y, poly[0].y)
			for i in range(1, poly.size() - 1):
				out.append({"region": id, "kind": "surface", "points": [
					origin, Vector3(poly[i].x, surface_y, poly[i].y), Vector3(poly[i + 1].x, surface_y, poly[i + 1].y)]})
		for i in poly.size():
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % poly.size()]
			var shared_bed := _same_bed(shared, a, b, id, regions)
			if shared_bed < 0 and not _covered(walls, a, b, floor_y, surface_y):
				_quad(out, id, a, b, floor_y, surface_y)
			var low := floor_y - UNDER_BED
			if not _covered(walls, a, b, low, floor_y):
				var skirt_a := a
				var skirt_b := b
				if shared_bed >= 0:
					var pair: Array = _inset(poly, a, b, 0.5)
					skirt_a = pair[0]
					skirt_b = pair[1]
				_quad(out, id, skirt_a, skirt_b, low, floor_y)
	return out

static func _quad(out: Array, id: int, a: Vector2, b: Vector2, y0: float, y1: float) -> void:
	out.append({"region": id, "kind": "skirt", "points": [
		Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y)]})
	out.append({"region": id, "kind": "skirt", "points": [
		Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)]})

## Pull a shared-bed edge into this polygon so each region's cluster draws its own under-bed wall.
static func _inset(poly: Array, a: Vector2, b: Vector2, amount: float) -> Array:
	var edge := b - a
	if edge.length_squared() < 0.01: return [a, b]
	var n := Vector2(-edge.y, edge.x).normalized()
	var center := Vector2.ZERO
	for p in poly:
		center += p as Vector2
	center /= float(poly.size())
	if n.dot(center - (a + b) * 0.5) < 0.0: n = -n
	return [a + n * amount, b + n * amount]

## Runtime liquid rows use id. The liquid pack uses region. Both are the native region number.
static func _region_id(region: Dictionary) -> int:
	if region.has("id"): return int(region.id)
	return int(region.get("region", -1))

static func _poly(polygon) -> Array:
	var out: Array = []
	for p in polygon:
		if p is Vector2:
			out.append(p)
		else:
			out.append(Vector2(float(p[0]), float(p[1])))
	return out

static func _key(a: Vector2, b: Vector2) -> String:
	var ax := roundi(a.x)
	var ay := roundi(a.y)
	var bx := roundi(b.x)
	var by := roundi(b.y)
	if ax > bx or (ax == bx and ay > by):
		var tx := ax
		ax = bx
		bx = tx
		var ty := ay
		ay = by
		by = ty
	return "%d,%d|%d,%d" % [ax, ay, bx, by]

static func _shared_edges(regions: Array) -> Dictionary:
	var shared: Dictionary = {}
	for index in regions.size():
		var region: Dictionary = regions[index]
		var poly: Array = _poly(region.polygon)
		for i in poly.size():
			var key := _key(poly[i], poly[(i + 1) % poly.size()])
			if not shared.has(key): shared[key] = []
			(shared[key] as Array).append(index)
	return shared

## Region id of a same-bed water neighbour on this edge, or -1 when the edge is a bank.
static func _same_bed(shared: Dictionary, a: Vector2, b: Vector2, id: int, regions: Array) -> int:
	var rows: Array = shared.get(_key(a, b), [])
	var mine := -1
	for index in regions.size():
		if _region_id(regions[index]) == id:
			mine = index
			break
	if mine < 0: return -1
	for index in rows:
		if int(index) == mine: continue
		if absf(float(regions[index].floor) - float(regions[mine].floor)) <= 30.0:
			return _region_id(regions[index])
	return -1

static func _index_walls(faces: Array) -> Dictionary:
	var grid: Dictionary = {}
	for item in faces:
		var face: Dictionary = item
		if str(face.get("kind", "")) != "wall": continue
		var pts: Array = face.points
		var mid := Vector2(float(pts[0][0]) + float(pts[1][0]), float(pts[0][2]) + float(pts[1][2])) * 0.5
		var lo := INF
		var hi := -INF
		for p in pts:
			lo = minf(lo, float(p[1]))
			hi = maxf(hi, float(p[1]))
		var cell := Vector2i(floori(mid.x / 256.0), floori(mid.y / 256.0))
		if not grid.has(cell): grid[cell] = []
		(grid[cell] as Array).append({"mid": mid, "lo": lo, "hi": hi})
	return grid

static func _covered(grid: Dictionary, a: Vector2, b: Vector2, y0: float, y1: float) -> bool:
	var mid := (a + b) * 0.5
	var cell := Vector2i(floori(mid.x / 256.0), floori(mid.y / 256.0))
	var need := y1 - y0
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			var rows: Array = grid.get(cell + Vector2i(ox, oy), [])
			for item in rows:
				var rec: Dictionary = item
				if _dist(rec.mid, a, b) > EDGE_DIST: continue
				var overlap: float = minf(float(rec.hi), y1) - maxf(float(rec.lo), y0)
				if overlap >= need - 1.0: return true
	return false

static func _dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.01: return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _mesh(quads: Array, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for item in quads:
		var quad: Dictionary = item
		var pts: Array = quad.points
		for p in pts:
			st.set_uv(Vector2.ZERO)
			st.add_vertex(p)
	return st.commit()
