extends StaticBody3D
## Collision for the original sword table = L3_DH static assembly 77 (template top child165 + four legs), drawn by the
## static-assembly renderer. The longplay (18:02-18:10) shows one long low black table with the sword, the mail and
## the two Champion Stones lying on it. Native item placements say h50, 22 units above the table top (h28); the port
## rests them on the top instead (docs/DEVIATIONS.md). Replaces the earlier authored brown table (owner report
## 2026-10-20 18:02, "2 tables here should just be one").
const PACK := "res://assets/lol2/generated/static_assemblies/L3_DH/assemblies.json"
const ASSEMBLY := 77
const TOP := 28.0

## Item `p` (bottom pivot) resting on the table top.
static func rest(p: Vector3) -> Vector3:
	return Vector3(p.x, TOP, p.z)

func _ready() -> void:
	name = "SwordTable77"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACK)) if FileAccess.file_exists(PACK) else null
	if not parsed is Dictionary: return
	# The top face of the slab: the highest face of child165 (four corners at h28).
	var top: Array = []
	for face in parsed.faces:
		if int(face.assembly) != ASSEMBLY: continue
		var flat := true
		for p in face.points: flat = flat and is_equal_approx(float(p[1]), TOP)
		if flat: top = face.points
	if top.size() != 4: return
	var a := Vector3(top[0][0], 0, top[0][2]); var b := Vector3(top[1][0], 0, top[1][2]); var c := Vector3(top[2][0], 0, top[2][2])
	var width := a.distance_to(b); var depth := b.distance_to(c)
	var centre := (a + c) / 2.0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, TOP, depth)
	collider.shape = box
	collider.position = centre + Vector3(0, TOP / 2.0, 0)
	# Local X along the a->b edge (Godot Y rotation maps X to (cos, 0, -sin)).
	collider.rotation.y = atan2(-(b - a).z, (b - a).x)
	add_child(collider)
