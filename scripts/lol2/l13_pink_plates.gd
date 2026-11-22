extends RefCounted
## L13 pink plates: collide on their top only (lead 2026-11-13 L13 HEADROOM, Sol's STOP B pink ledges; DEVIATIONS row 0651).
## The pink stair before the plates is 21 treads (nav regions 837..859, 50 apart). Each tread carries a pink plate, static
## assembly template 10 child 12 (placements static_55..static_75), 2 thick, its top 22 above its own tread. The plates are
## rotated squares, so a plate reaches over the inner part of the tread below it: plate 71 (top -858, tread 848) hangs 70
## above tread 850 (-930). With every plate face solid, a valid jump from there hits its underside (faces 5204/5205) and
## stalls short of the next tread. Here the plates keep only their top face, one-sided and facing up: the body rises
## through a plate from below and lands on its top from above, where the drawn step is. Drawing is unchanged.
## The risers: each tread's source wall from its floor up to the next tread's floor is linked to that tread, so the
## region-edge rule leaves it open, and the body slid under the next tread's edge into the void below the stair (r19h
## real input, ledge 3). The risers (21 faces over 20 rises) collide here, both-sided; the next tread is reached by a jump, as drawn.
## Meta lol2_pink_plates_off = before (every plate face in the static collision, risers open).
const AREA := "L13_RC"
const FIRST := 55
const LAST := 75
## The pink treads bottom to top (tests/fixtures/l13_pink_steps_walk.json), 50 apart, the last 40.
const TREADS := [837, 850, 848, 846, 844, 842, 840, 839, 854, 852, 878, 876, 874, 872, 870, 869, 867, 865, 863, 861, 859]

static func enabled(tree: SceneTree, area: String) -> bool:
	return area == AREA and not tree.has_meta("lol2_pink_plates_off")

static func is_plate(face: Dictionary) -> bool:
	if str(face.get("placement_kind", "")) != "static_assembly" or int(face.get("template", -1)) != 10 or int(face.get("child", -1)) != 12: return false
	var placement := str(face.get("placement", ""))
	if not placement.begins_with("static_"): return false
	var index := int(placement.trim_prefix("static_"))
	return index >= FIRST and index <= LAST

## The top faces of the plates, as one-sided upward triangles, on their own static body.
static func attach(map: Node3D, faces: Array) -> int:
	var tops: Dictionary = {}
	for face: Dictionary in faces:
		if not is_plate(face): continue
		var ys: Array = face.points.map(func(p): return float(p[1]))
		if ys.max() - ys.min() > 0.01: continue
		var key := str(face.placement)
		if not tops.has(key) or float(tops[key].points[0][1]) < ys[0]: tops[key] = face
	var triangles := PackedVector3Array()
	var floors: Dictionary = {}
	for face: Dictionary in faces:
		if str(face.get("kind", "")) == "floor" and face.get("region") != null and int(face.region) in TREADS: floors[int(face.region)] = float(face.points[0][1])
	var risers := PackedVector3Array()
	for face: Dictionary in faces:
		if str(face.get("kind", "")) != "source_wall" or face.get("region") == null: continue
		var at := TREADS.find(int(face.region))
		if at < 0 or at + 1 >= TREADS.size(): continue
		var ys: Array = face.points.map(func(p): return float(p[1]))
		if absf(ys.min() - floors[TREADS[at]]) > 0.01 or absf(ys.max() - floors[TREADS[at + 1]]) > 0.01: continue
		for i in [0, 1, 2, 0, 2, 3]: risers.append(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
	map.set_meta("pink_risers", risers.size() / 6)
	# Overhang trim (row 0666): a plate top collides only over its own tread (the tread 22 below it), not where it hangs
	# over the tread beneath, so a jump from that lower tread no longer rises into the plate and hangs on the next edge.
	var tread_polys: Dictionary = {}
	for face: Dictionary in faces:
		if str(face.get("kind", "")) != "floor" or face.get("region") == null or not int(face.region) in TREADS: continue
		var poly := PackedVector2Array()
		for point in face.points: poly.append(Vector2(point[0], point[2]))
		if not tread_polys.has(int(face.region)): tread_polys[int(face.region)] = []
		tread_polys[int(face.region)].append(poly)
	var trimmed := 0
	for face: Dictionary in tops.values():
		var y := float(face.points[0][1])
		var plate := PackedVector2Array()
		for point in face.points: plate.append(Vector2(point[0], point[2]))
		var own := -1
		for region: int in floors:
			if y - float(floors[region]) > 0.0 and y - float(floors[region]) <= 30.0: own = region
		var pieces: Array = [plate]
		if own >= 0:
			pieces = []
			for poly: PackedVector2Array in tread_polys[own]: pieces.append_array(Geometry2D.intersect_polygons(plate, poly))
			trimmed += 1
		for piece: PackedVector2Array in pieces:
			var index := Geometry2D.triangulate_polygon(piece)
			for i in range(0, index.size(), 3):
				var a := Vector3(piece[index[i]].x, y, piece[index[i]].y)
				var b := Vector3(piece[index[i + 1]].x, y, piece[index[i + 1]].y)
				var c := Vector3(piece[index[i + 2]].x, y, piece[index[i + 2]].y)
				# Godot's front face is the clockwise one seen from the front: keep the order whose normal (b-a)x(c-a) points down.
				if (b - a).cross(c - a).y > 0.0: triangles.append_array([a, c, b])
				else: triangles.append_array([a, b, c])
	map.set_meta("pink_tops_trimmed", trimmed)
	if triangles.is_empty(): return 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = false
	shape.set_faces(triangles)
	var body := StaticBody3D.new()
	body.name = "L13PinkPlateTops"
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	if not risers.is_empty():
		var walls := ConcavePolygonShape3D.new()
		walls.backface_collision = true
		walls.set_faces(risers)
		var wall_collider := CollisionShape3D.new()
		wall_collider.name = "Risers"
		wall_collider.shape = walls
		body.add_child(wall_collider)
	map.add_child(body)
	if not risers.is_empty():
		var stair := AABB(risers[0], Vector3.ZERO)
		for point in risers: stair = stair.expand(point)
		var release := WedgeRelease.new()
		release.name = "L13PinkWedgeRelease"
		release.map = map
		release.stair = stair.grow(40.0)
		map.add_child(release)
	return tops.size()
const WedgeRelease := preload("res://scripts/lol2/l13_pink_wedge_release.gd")
