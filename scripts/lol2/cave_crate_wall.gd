extends RefCounted
## J01. Wall record 1485 is the drawn riser on region 1081 edge 3 (heights -215..-130). The span builder
## defers that edge, so the shell has no collision there. This quad is the only source wall that blocks.
const RECORD := 1485

static func is_riser(wall: Variant) -> bool:
	return wall is Dictionary and int(wall.get("record", -1)) == RECORD

static func corners(wall: Dictionary, translation: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in wall.get("points_godot", []):
		out.append(Vector3(float(p[0]), float(p[1]), float(p[2])) + translation)
	return out

static func add_collider(parent: Node3D, wall: Dictionary, translation: Vector3) -> StaticBody3D:
	var pts := corners(wall, translation)
	var body := StaticBody3D.new()
	body.name = "CrateRiser1485"
	var shape := CollisionShape3D.new()
	var poly := ConcavePolygonShape3D.new()
	poly.backface_collision = true
	var faces := PackedVector3Array()
	for i in [0, 1, 2, 0, 2, 3]:
		faces.append(pts[i])
	poly.set_faces(faces)
	shape.shape = poly
	body.add_child(shape)
	parent.add_child(body)
	return body
