extends Node3D
## Ten native neighbours from the floor-30 bank onto floor 95. The port floor quad on each
## low region rises from y=30 to y=100 at about 54 degrees, so the body does not stand on it.
## The quad stays drawn. Its collision is replaced by a prism that meets floor 30 and floor 95
## at 40 degrees, inside the 45-degree floor limit. Same idea as the stream-deck skirts.
const HIGH_OF := {
	4945: 4932, 4947: 4931, 4949: 4968, 4953: 4969, 4954: 4970,
	4958: 4972, 4959: 4971, 4961: 4967, 4965: 4930, 4966: 4929,
}
const LOW_Y := 30.0
const HIGH_Y := 95.0
const SLOPE_DEG := 40.0
const OVERLAP := 8.0
const THICK := 8.0

static func owns(face: Dictionary) -> bool:
	return str(face.get("kind", "")) == "floor" and HIGH_OF.has(int(face.get("region", -1)))

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_terrace_lips.gd").new()
	n.name = "L16TerraceLips"
	map.add_child(n)
	return n

## Slab over one link. The first four points are the walk surface: two on the terrace, two on the bank.
static func slab(raw: Array) -> PackedVector3Array:
	var lows: Array[Vector3] = []
	var highs: Array[Vector3] = []
	var sum := 0.0
	for item in raw:
		var row: Array = item
		sum += float(row[1])
	var mid_y := sum / float(raw.size())
	for item in raw:
		var row: Array = item
		var v := Vector3(float(row[0]), float(row[1]), float(row[2]))
		if v.y <= mid_y:
			lows.append(v)
		else:
			highs.append(v)
	var out := PackedVector3Array()
	if lows.size() != 2 or highs.size() != 2:
		return out
	var low_mid := (lows[0] + lows[1]) * 0.5
	var high_mid := (highs[0] + highs[1]) * 0.5
	var down := Vector3(low_mid.x - high_mid.x, 0.0, low_mid.z - high_mid.z)
	var run := down.length()
	if run < 1.0:
		return out
	down /= run
	var need := (HIGH_Y - LOW_Y) / tan(deg_to_rad(SLOPE_DEG))
	var extra := maxf(0.0, need - (run + OVERLAP))
	var top0 := Vector3(highs[0].x - down.x * OVERLAP, HIGH_Y, highs[0].z - down.z * OVERLAP)
	var top1 := Vector3(highs[1].x - down.x * OVERLAP, HIGH_Y, highs[1].z - down.z * OVERLAP)
	var base0 := Vector3(lows[0].x + down.x * extra, LOW_Y, lows[0].z + down.z * extra)
	var base1 := Vector3(lows[1].x + down.x * extra, LOW_Y, lows[1].z + down.z * extra)
	var drop := Vector3(0.0, THICK, 0.0)
	out.append(top0)
	out.append(top1)
	out.append(base0)
	out.append(base1)
	out.append(top0 - drop)
	out.append(top1 - drop)
	out.append(base0 - drop)
	out.append(base1 - drop)
	return out

static func slope_degrees(points: PackedVector3Array) -> float:
	if points.size() < 3:
		return 90.0
	var n: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	if n.length() < 0.001:
		return 90.0
	n = n.normalized()
	if n.y < 0.0:
		n = -n
	return rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))

func _ready() -> void:
	var map: Node = get_parent()
	var path := str(map.get("geometry_file"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	var faces: Array = data.get("faces", [])
	for item in faces:
		if not item is Dictionary:
			continue
		var face: Dictionary = item
		if not owns(face):
			continue
		var pts := slab(face.get("points", []))
		if pts.size() != 8:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var hull := ConvexPolygonShape3D.new()
		hull.points = pts
		var shape := CollisionShape3D.new()
		shape.shape = hull
		body.add_child(shape)
		add_child(body)
