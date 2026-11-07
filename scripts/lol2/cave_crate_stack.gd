extends Node
## J01 crate stack (H16, K13a). Controls 94, 95, 96, 97, 112, 121, and 122 have no move opcode.
## The player shove is the adapter. A crate pushed onto another rests on that top. No fake stair.
## The climb is the two mace placements at height -130. Their dword 0x8FCB4F6D is item "2-Br Mace"
## (identity 2412466029). The third record, region 1171, is the bridge room and is not this stack.
## Those two rows are not in the L1_DC.json object table, and the pickup callee was not read, so no
## item is spawned. Other source walls stay drawn only.
const IDS := [94, 95, 96, 97, 112, 121, 122]
const FLOOR_Y := -215.0
const LIP_Y := -130.0
const MACE_IDENTITY := 2412466029
const MACE := [
	{"x": 417.0, "y": 12444.0, "h": -130.0, "region": 1092},
	{"x": 471.0, "y": 12480.0, "h": -130.0, "region": 1099},
]
const NOT_THIS_STACK := {"x": 329.0, "y": 16631.0, "h": -285.0, "region": 1171}
const RISER_A := Vector2(474, -12338)
const RISER_B := Vector2(586, -12403)
const PUSH := 8.0
const PLAYER_R := 8.0
var host: Node3D
var assemblies
var centers: Dictionary = {}
var sizes: Dictionary = {}
var homes: Dictionary = {}

static func attach(walkthrough: Node3D) -> Node:
	var n = load("res://scripts/lol2/cave_crate_stack.gd").new()
	n.name = "CaveCrateStack"
	walkthrough.add_child(n)
	var error: String = n.setup(walkthrough)
	if not error.is_empty(): push_error(error)
	return n

static func is_stack_mace(row: Dictionary) -> bool:
	if absf(float(row.get("h", 0.0)) - LIP_Y) > 0.1: return false
	for m in MACE:
		var same_x: bool = absf(float(row.get("x", 0.0)) - float(m.x)) < 0.1
		var same_y: bool = absf(float(row.get("y", 0.0)) - float(m.y)) < 0.1
		if same_x and same_y and int(row.get("region", -1)) == int(m.region): return true
	return false

static func top_y(heights: Array) -> float:
	var y := FLOOR_Y
	for h in heights: y += float(h)
	return y

static func reaches_lip(heights: Array) -> bool:
	return top_y(heights) >= LIP_Y

static func overlaps_xz(a: Vector3, asz: Vector3, b: Vector3, bsz: Vector3) -> bool:
	var hit_x: bool = absf(a.x - b.x) < (asz.x + bsz.x) * 0.5
	var hit_z: bool = absf(a.z - b.z) < (asz.z + bsz.z) * 0.5
	var hit: bool = hit_x and hit_z
	return hit

static func riser_gap(center: Vector3) -> float:
	var flat := Vector2(center.x, center.z)
	return Geometry2D.get_closest_point_to_segment(flat, RISER_A, RISER_B).distance_to(flat)

## A shove that lands on another crate snaps onto that crate's top. A clear shove stays on the floor.
static func shove_onto(centers_in: Dictionary, sizes_in: Dictionary, id: int, delta: Vector3) -> Vector3:
	var c: Vector3 = centers_in[id]
	var nxt := Vector3(c.x + delta.x, c.y, c.z + delta.z)
	var mine: Vector3 = sizes_in[id]
	var best_top := -1.0e9
	var best_id := -1
	for other in centers_in:
		if int(other) == id: continue
		var o: Vector3 = centers_in[other]
		if overlaps_xz(nxt, mine, o, sizes_in[other]):
			var otop: float = o.y + sizes_in[other].y * 0.5
			if otop > best_top:
				best_top = otop
				best_id = int(other)
	if best_id >= 0:
		var onto: Vector3 = centers_in[best_id]
		return Vector3(onto.x, best_top + mine.y * 0.5, onto.z)
	return nxt

static func support_top(centers_in: Dictionary, sizes_in: Dictionary, id: int) -> float:
	var me: Vector3 = centers_in[id]
	var mine: Vector3 = sizes_in[id]
	var top := FLOOR_Y
	var my_bottom := me.y - mine.y * 0.5
	for other in centers_in:
		if int(other) == id: continue
		var o: Vector3 = centers_in[other]
		if not overlaps_xz(me, mine, o, sizes_in[other]): continue
		var otop: float = o.y + sizes_in[other].y * 0.5
		if otop > my_bottom + 0.5: continue
		if otop > top: top = otop
	return top

static func rest_all(centers_in: Dictionary, sizes_in: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in centers_in: out[id] = centers_in[id]
	var ids: Array = out.keys()
	ids.sort_custom(func(a, b): return float(out[a].y) < float(out[b].y))
	for id in ids:
		var top := support_top(out, sizes_in, int(id))
		var c: Vector3 = out[id]
		out[id] = Vector3(c.x, top + sizes_in[id].y * 0.5, c.z)
	return out

func setup(walkthrough: Node3D) -> String:
	host = walkthrough
	assemblies = host.get("static_assemblies")
	if assemblies == null: return "Cave crates need static assemblies."
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L1_DC.json"))
	if not parsed is Dictionary: return "Cave crate collision is missing."
	var offset := Vector3.ZERO
	if str(assemblies.data.get("render", "")) == "indexed": offset = host.native_translation
	for id in IDS:
		var b: Dictionary = parsed.boxes[str(id)]
		sizes[id] = Vector3(float(b.width), float(b.height), float(b.depth))
		var body: StaticBody3D = assemblies.solid_bodies.get(id)
		if body == null:
			var made: StaticBody3D = assemblies.box_body(id, b, offset)
			if made == null: return "Cave crate %d has no box." % id
			assemblies.add_child(made)
			assemblies.solid_bodies[id] = made
			body = made
		homes[id] = body.position
		centers[id] = body.position
	if host.get("player") is CollisionObject3D: host.player.collision_mask |= assemblies.SCENERY_LAYER
	return ""

func _push(id: int, player_pos: Vector3) -> Vector3:
	var c: Vector3 = centers[id]
	var half: float = sizes[id].y * 0.5
	var feet: float = player_pos.y - 32.0
	var overlaps_y: bool = feet < c.y + half and feet + 64.0 > c.y - half
	if not overlaps_y: return Vector3.ZERO
	var away := Vector3(c.x - player_pos.x, 0, c.z - player_pos.z)
	var reach: float = PLAYER_R + maxf(sizes[id].x, sizes[id].z) * 0.5
	if away.length() < 0.01 or away.length() > reach: return Vector3.ZERO
	return away.normalized() * minf(PUSH, reach - away.length() + 1.0)

func _physics_process(_delta: float) -> void:
	if assemblies == null or not is_instance_valid(host) or not host.get("player") is Node3D: return
	var player_pos: Vector3 = host.player.global_position
	var moved := false
	for id in IDS:
		var push := _push(id, player_pos)
		if push.length_squared() < 0.01: continue
		var nxt: Vector3 = shove_onto(centers, sizes, id, push)
		var radius: float = maxf(sizes[id].x, sizes[id].z) * 0.5
		var deeper: bool = riser_gap(nxt) + 0.05 < riser_gap(centers[id]) and riser_gap(nxt) < radius
		if not deeper:
			centers[id] = nxt
			moved = true
	if moved: centers = rest_all(centers, sizes)
	for id in IDS:
		var body: StaticBody3D = assemblies.solid_bodies.get(id)
		if body == null: continue
		body.position = centers[id]
		assemblies.set_offset(id, centers[id] - homes[id])
