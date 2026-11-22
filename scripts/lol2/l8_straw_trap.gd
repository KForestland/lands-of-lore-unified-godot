extends Node3D
const RESTORE_ON := ["load", "arrival"]
## L8 straw pit on the Larkhon approach. Assemblies 93 and 94 (template 22) start absent
## (placement word +8 bit 0x1000). Straw cover 95 stays (word 0x401, not solid). The stake
## line on control 112 stays (word 0x481, mode 0). Region 3255 group 1902 opcode 16 stores
## 1 at control 112 byte +0x25. Group 13046 links 93 and 94 only for kind 6 value 7 when
## that byte is 1. The caller of kind 6 value 7 is not known. Group 12994 (control 112
## kind 5 value 4) releases the player from cover 95 and queues opcode 18. That motion
## reader was not entered. Opcode 9 arm 6 was not entered.
## Adapter: a walk lid over the straw, because 95 has no solid bit, and the ramps appear
## after the body has landed. That reveal is not group 13046. The source boxes stay
## non-solid so they do not cork the plate. A slope from that plate onto region 3263
## is the way out. That slope is not opcode 18.
const KEY: String = "l8_straw_trap"
const RAMPS: Array[int] = [93, 94]
const PIT_REGION := 3255
const STRAW := 95
const OP9_ENTERED := false
const OP18_ENTERED := false
const CALLER7_KNOWN := false
const Body := preload("res://scripts/lol2/player_form_body.gd")
var host: Node3D
var _pit := PackedVector2Array()
var _stake_rows: Array[int] = []

static func initial() -> Dictionary:
	return {"version": 1, "sprung": false}

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid straw trap."
	if not saved is Dictionary or saved.size() != 2 or int(saved.get("version", 0)) != 1 or not saved.get("sprung") is bool:
		return "Invalid straw trap."
	return ""

static func owns(face: Dictionary) -> bool:
	if face.get("kind") != "movable" or face.get("placement_kind") != "static_assembly": return false
	return int(face.get("source_index", -1)) in RAMPS

## Straw 95 is present and not solid (word +8 is 0x401, bit 0x80 clear). Its quads stay drawn.
## They are not a floor: the lid is the walk surface until the step.
static func cover(face: Dictionary) -> bool:
	if face.get("kind") != "movable" or face.get("placement_kind") != "static_assembly": return false
	var source_v: Variant = face.get("source_index", -1)
	return (source_v is int or source_v is float) and int(source_v) == STRAW

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l8_straw_trap.gd").new()
	node.host = map
	node.name = "L8StrawTrap"
	map.add_child(node)
	return node

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func covers(x: float, z: float) -> bool:
	return _inside(x, z)

func stake_scale() -> float:
	if _stake_rows.is_empty(): return -1.0
	var entry: Array = host.prop_placements[_stake_rows[0]]
	var multi: MultiMesh = entry[0]
	return multi.get_instance_transform(int(entry[1])).basis.x.length()

func restore() -> void:
	var assemblies: Variant = host.get("preview_assemblies")
	if assemblies == null or not is_instance_valid(assemblies): return
	var sprung := bool(state().sprung)
	# A sprung trap shows its open mouth (the source boxes' meshes) whether the body
	# is down on the plate, still falling, or long gone: Kimi K48 - a reload after the
	# escape drew the straw lid gone but no ramps, so the pit looked covered. The
	# solids of those boxes stay off in every case, or the landing is corked.
	var show := sprung
	# The way out (the slope from the plate) waits for the body to be down on the plate: raised at the moment of
	# springing it would catch the falling body at the rim.
	var landed := sprung and _on_pit_floor()
	for id in RAMPS:
		assemblies.set_present(id, show)
		if show and assemblies.solid_bodies.has(id):
			var solid: StaticBody3D = assemblies.solid_bodies[id]
			solid.collision_layer = 0
	_sync_lid(not sprung)
	_sync_stakes(not show)
	_sync_exit(landed)

func _ready() -> void:
	_read_pack()
	restore()

## Called from the host move, because a test can drive move_grounded with the scene's
## physics callback off. A grounded foot inside region 3255 springs the lid.
## Once the body is standing on the pit floor, the same call shows the stairs.
func watch() -> void:
	if host.get_tree().paused or bool(host.flying): return
	var body := host.player as CharacterBody3D
	if body == null: return
	if bool(state().sprung):
		if _on_pit_floor(): restore()
		return
	if not body.is_on_floor(): return
	var feet := body.position.y - Body.FOOT_OFFSET
	if feet < -8.0 or feet > 8.0 or absf(body.velocity.y) > 30.0: return
	if not _inside(body.position.x, body.position.z): return
	host.quest_state[KEY] = {"version": 1, "sprung": true}
	restore()

func _physics_process(_delta: float) -> void:
	watch()

## True once the body is down on the plate. A save reload has not stepped yet, so a
## resting body counts too. A body still falling does not.
func _on_pit_floor() -> bool:
	var body := host.player as CharacterBody3D
	if body == null: return true
	if body.position.y >= -30.0: return false
	return body.is_on_floor() or absf(body.velocity.y) < 1.0

func _read_pack() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(host.geometry_file)))
	if not parsed is Dictionary:
		push_error("Straw trap pack missing")
		return
	var data: Dictionary = parsed
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	var straw_faces := 0
	for face_v in data.get("faces", []):
		if not face_v is Dictionary: continue
		var face: Dictionary = face_v
		var region_v: Variant = face.get("region", -1)
		if (region_v is int or region_v is float) and int(region_v) == PIT_REGION and str(face.get("kind", "")) == "floor" and _pit.is_empty():
			for point_v in face.get("points", []):
				var point: Array = point_v
				_pit.append(Vector2(float(point[0]), float(point[2])))
		var source_v: Variant = face.get("source_index", -1)
		if not (source_v is int or source_v is float) or int(source_v) != STRAW or str(face.get("placement_kind", "")) != "static_assembly": continue
		straw_faces += 1
		for point_v in face.get("points", []):
			var point: Array = point_v
			min_x = minf(min_x, float(point[0]))
			max_x = maxf(max_x, float(point[0]))
			min_z = minf(min_z, float(point[2]))
			max_z = maxf(max_z, float(point[2]))
	if _pit.size() < 3 or straw_faces == 0:
		push_error("Straw trap pit or cover missing")
		return
	_lid_min = Vector2(min_x, min_z)
	_lid_max = Vector2(max_x, max_z)
	var props: Array = data.get("props", [])
	for i in props.size():
		if not props[i] is Dictionary: continue
		var place := str((props[i] as Dictionary).get("placement", ""))
		if place == "static_93" or place == "static_94": _stake_rows.append(-1 - i)

var _lid_min := Vector2.ZERO
var _lid_max := Vector2.ZERO

## The plate under the straw (control 112) is the floor of the hole, at y=-65.
## Opcode 18 was not entered. A slope rises from that plate to y=0 while still
## inside the pit, then a flat crosses onto region 3263. About 32 degrees.
## Not a source box.
func _sync_exit(up: bool) -> void:
	var existing := get_node_or_null("StrawExit")
	if not up:
		if existing != null: existing.queue_free()
		return
	if existing != null: return
	var body := StaticBody3D.new()
	body.name = "StrawExit"
	body.collision_layer = 1 << 8
	body.collision_mask = 0
	body.add_child(_wedge(Vector3(4264, -65, 960), Vector3(4316, -65, 960), Vector3(4264, 0, 853), Vector3(4316, 0, 853), 8.0))
	body.add_child(_wedge(Vector3(4264, 0, 853), Vector3(4316, 0, 853), Vector3(4264, 0, 800), Vector3(4316, 0, 800), 8.0))
	add_child(body)

func _wedge(a: Vector3, b: Vector3, c: Vector3, d: Vector3, thick: float) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	points.append(a)
	points.append(b)
	points.append(c)
	points.append(d)
	points.append(a + Vector3(0, -thick, 0))
	points.append(b + Vector3(0, -thick, 0))
	points.append(c + Vector3(0, -thick, 0))
	points.append(d + Vector3(0, -thick, 0))
	hull.points = points
	shape.shape = hull
	return shape

func _sync_lid(up: bool) -> void:
	var existing := get_node_or_null("StrawLid")
	if not up:
		if existing != null:
			(existing as CollisionObject3D).collision_layer = 0
			existing.queue_free()
		return
	if existing != null or _lid_max.x <= _lid_min.x: return
	var body := StaticBody3D.new()
	body.name = "StrawLid"
	body.collision_layer = 1 << 8
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_lid_max.x - _lid_min.x, 4.0, _lid_max.y - _lid_min.y)
	shape.shape = box
	shape.position = Vector3((_lid_min.x + _lid_max.x) * 0.5, -2.0, (_lid_min.y + _lid_max.y) * 0.5)
	body.add_child(shape)
	add_child(body)

func _sync_stakes(hidden: bool) -> void:
	var placements: Dictionary = host.prop_placements
	for row in _stake_rows:
		if not placements.has(row): continue
		var entry: Array = placements[row]
		var multi: MultiMesh = entry[0]
		var pose := Transform3D(Basis(), entry[2] as Vector3)
		if hidden: pose.basis = Basis.from_scale(Vector3.ZERO)
		multi.set_instance_transform(int(entry[1]), pose)

func _inside(x: float, z: float) -> bool:
	var inside := false
	var count := _pit.size()
	if count < 3: return false
	var j := count - 1
	for i in count:
		var xi := _pit[i].x
		var zi := _pit[i].y
		var xj := _pit[j].x
		var zj := _pit[j].y
		if ((zi > z) != (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi): inside = not inside
		j = i
	return inside
