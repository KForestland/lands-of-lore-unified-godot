extends Node
## J01 crate stack (H16, K13a). Controls 94, 95, 96, 97, 112, 121, and 122 have no events and no opcode 18.
## The player shove is the adapter. A crate pushed onto another rests on that top. No fake stair.
## E lifts the faced crate and E sets it down on the floor or on another crate. That carry is also an adapter:
## the hintbook says to stack the boxes, and it does not name a key. The pillar grasp is a different sentence.
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
## Lift reaches past the shove, so E can take a crate the body is not already pushing.
const LIFT_PAST_SHOVE := 24.0
const CARRY_GAP := 4.0
var carried := -1
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

static func support_top(centers_in: Dictionary, sizes_in: Dictionary, id: int, floor_y: float = FLOOR_Y) -> float:
	var me: Vector3 = centers_in[id]
	var mine: Vector3 = sizes_in[id]
	var top := floor_y
	var my_bottom := me.y - mine.y * 0.5
	for other in centers_in:
		if int(other) == id: continue
		var o: Vector3 = centers_in[other]
		if not overlaps_xz(me, mine, o, sizes_in[other]): continue
		var otop: float = o.y + sizes_in[other].y * 0.5
		if otop > my_bottom + 0.5: continue
		if otop > top: top = otop
	return top

static func rest_all(centers_in: Dictionary, sizes_in: Dictionary, floor_y: float = FLOOR_Y, floors: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for id in centers_in: out[id] = centers_in[id]
	var ids: Array = out.keys()
	ids.sort_custom(func(a, b): return float(out[a].y) < float(out[b].y))
	for id in ids:
		var mine_floor := floor_y
		if floors.has(id):
			mine_floor = float(floors[id])
		var top := support_top(out, sizes_in, int(id), mine_floor)
		var c: Vector3 = out[id]
		out[id] = Vector3(c.x, top + sizes_in[id].y * 0.5, c.z)
	return out

## Homes already include the cave translation. The native floor constant does not.
func _world_floor() -> float:
	var id: int = int(IDS[0])
	return float(homes[id].y) - float(sizes[id].y) * 0.5

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

## Human 15, lizard 23, beast 8. The old reach used 8 for every form, so a human
## stopped on the crate and the shove never started.
func _body_radius() -> float:
	var form: int = 0
	if host != null:
		var raw: Variant = host.get("player_form")
		if raw != null:
			form = int(raw)
	var radii: Array = preload("res://scripts/lol2/player_form_body.gd").RADII
	if form < 0 or form >= radii.size():
		form = 0
	return float(radii[form])

static func validate(state: Variant) -> String:
	if not state is Dictionary: return "Cave crates are not an object."
	if int(state.get("version", -1)) != 1: return "Cave crate version is not 1."
	var carried_id := int(state.get("carried", -2))
	if carried_id != -1 and not carried_id in IDS: return "Cave crate carry is unknown."
	var at: Variant = state.get("at")
	if not at is Dictionary: return "Cave crate places are missing."
	var places: Dictionary = at
	if places.size() != IDS.size(): return "Cave crate places are missing."
	for id in IDS:
		var row: Variant = places.get(str(id))
		if not row is Array or row.size() != 3: return "Cave crate %d has no place." % id
		for component in row:
			if not (component is int or component is float) or not is_finite(float(component)) or absf(float(component)) > 200000.0:
				return "Cave crate %d is out of range." % id
	return ""

func checkpoint() -> Dictionary:
	var at: Dictionary = {}
	for id in IDS:
		var c: Vector3 = centers[id]
		at[str(id)] = [c.x, c.y, c.z]
	return {"version": 1, "carried": carried, "at": at}

func restore(state: Variant) -> void:
	if validate(state) != "": return
	var packet: Dictionary = state
	var at: Dictionary = packet.at
	for id in IDS:
		var row: Array = at[str(id)]
		centers[id] = Vector3(float(row[0]), float(row[1]), float(row[2]))
	carried = int(packet.carried)
	_apply_bodies()

func _note(text: String) -> void:
	var hud: Variant = host.get("interface_hud")
	if hud is Node:
		var hint: Variant = hud.get("hint")
		if hint is Label:
			hint.text = text

func _forward() -> Vector3:
	var cam: Variant = host.get("camera")
	var forward := Vector3.ZERO
	if cam is Camera3D:
		forward = -(cam as Camera3D).global_transform.basis.z
	elif host.get("player") is Node3D:
		forward = -host.player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	return forward.normalized()

func _lift_reach(id: int) -> float:
	var corner: float = 0.5 * Vector2(sizes[id].x, sizes[id].z).length()
	return _body_radius() + corner + 1.0 + LIFT_PAST_SHOVE

func _nearest_faced(skip: int) -> int:
	var origin: Vector3 = host.player.global_position
	var forward := _forward()
	var best := -1
	var best_d := 1.0e9
	for id in IDS:
		if int(id) == skip: continue
		var c: Vector3 = centers[id]
		var away := Vector3(c.x - origin.x, 0.0, c.z - origin.z)
		var dist := away.length()
		if dist < 0.01 or dist > _lift_reach(int(id)): continue
		if away.normalized().dot(forward) < 0.5: continue
		var half: float = sizes[id].y * 0.5
		var feet: float = origin.y - 32.0
		if feet > c.y + half + 16.0: continue
		if feet + 72.0 < c.y - half: continue
		var take := false
		if best < 0 or dist < best_d - 0.5:
			take = true
		elif absf(dist - best_d) <= 0.5:
			var higher: Vector3 = centers[best]
			if c.y > higher.y:
				take = true
		if take:
			if dist < best_d:
				best_d = dist
			best = int(id)
	return best

func _carry_spot() -> Vector3:
	var size: Vector3 = sizes[carried]
	var ahead: float = _body_radius() + maxf(size.x, size.z) * 0.5 + CARRY_GAP
	var player: Node3D = host.player
	var spot: Vector3 = player.global_position + _forward() * ahead
	var feet: float = player.global_position.y - 32.0
	spot.y = feet + 36.0 + size.y * 0.5
	return spot

## The floor under a drop. A lip and the bridge room are not the stack-room floor.
func _floor_at(x: float, z: float, from_y: float) -> float:
	var fallback := _world_floor()
	if not is_inside_tree() or not is_instance_valid(host):
		return fallback
	var world: World3D = host.get_world_3d()
	if world == null:
		return fallback
	var player_v: Variant = host.get("player")
	var exclude: Array[RID] = []
	if player_v is CollisionObject3D:
		exclude.append((player_v as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y + 4.0, z), Vector3(x, from_y - 800.0, z), 1, exclude)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return fallback
	var normal: Vector3 = hit.normal
	if absf(normal.y) < 0.5:
		return fallback
	var at: Vector3 = hit.position
	return at.y

func _rest(subset: Dictionary) -> void:
	var floors: Dictionary = {}
	for id in subset:
		var c: Vector3 = subset[id]
		floors[id] = _floor_at(c.x, c.z, c.y)
	var grounded: Dictionary = rest_all(subset, sizes, _world_floor(), floors)
	for id in grounded:
		centers[int(id)] = grounded[id]

## E lifts the faced crate. E again sets it on the faced crate, or on the floor under the drop.
func try_use() -> bool:
	if assemblies == null or not is_instance_valid(host) or not host.get("player") is Node3D: return false
	if carried >= 0:
		var id := carried
		var onto := _nearest_faced(id)
		var size: Vector3 = sizes[id]
		if onto >= 0:
			var o: Vector3 = centers[onto]
			centers[id] = Vector3(o.x, o.y + sizes[onto].y, o.z)
		else:
			var spot := _carry_spot()
			var floor_y := _floor_at(spot.x, spot.z, spot.y)
			centers[id] = Vector3(spot.x, floor_y + size.y * 0.5, spot.z)
		carried = -1
		var grounded: Dictionary = {}
		for each_id in IDS:
			grounded[each_id] = centers[each_id]
		_rest(grounded)
		_note("Set the crate down.")
		_apply_bodies()
		return true
	var found := _nearest_faced(-1)
	if found < 0: return false
	carried = found
	var above: Dictionary = {}
	for each_id in IDS:
		if int(each_id) == carried: continue
		above[each_id] = centers[each_id]
	_rest(above)
	centers[found] = _carry_spot()
	_note("Carrying a crate.")
	_apply_bodies()
	return true

func _apply_bodies() -> void:
	if assemblies == null: return
	var layer := int(assemblies.SCENERY_LAYER)
	for id in IDS:
		var body: StaticBody3D = assemblies.solid_bodies.get(id)
		if body == null: continue
		body.position = centers[id]
		assemblies.set_offset(id, centers[id] - homes[id])
		body.collision_layer = 0 if int(id) == carried else layer

func _push(id: int, player_pos: Vector3) -> Vector3:
	var c: Vector3 = centers[id]
	var half: float = sizes[id].y * 0.5
	var feet: float = player_pos.y - 32.0
	var overlaps_y: bool = feet < c.y + half and feet + 64.0 > c.y - half
	if not overlaps_y: return Vector3.ZERO
	var away := Vector3(c.x - player_pos.x, 0, c.z - player_pos.z)
	var corner: float = 0.5 * Vector2(sizes[id].x, sizes[id].z).length()
	var reach: float = _body_radius() + corner + 1.0
	if away.length() < 0.01 or away.length() > reach: return Vector3.ZERO
	return away.normalized() * minf(PUSH, reach - away.length())

func _physics_process(_delta: float) -> void:
	if assemblies == null or not is_instance_valid(host) or not host.get("player") is Node3D: return
	var player_pos: Vector3 = host.player.global_position
	var moved := false
	for id in IDS:
		if int(id) == carried: continue
		var push := _push(id, player_pos)
		if push.length_squared() < 0.01: continue
		var shove_centers: Dictionary = centers.duplicate()
		if carried >= 0: shove_centers.erase(carried)
		var nxt: Vector3 = shove_onto(shove_centers, sizes, id, push)
		var radius: float = maxf(sizes[id].x, sizes[id].z) * 0.5
		var deeper: bool = riser_gap(nxt) + 0.05 < riser_gap(centers[id]) and riser_gap(nxt) < radius
		if not deeper:
			centers[id] = nxt
			moved = true
	if moved:
		var grounded: Dictionary = {}
		for id in IDS:
			if int(id) == carried: continue
			grounded[id] = centers[id]
		_rest(grounded)
	if carried >= 0:
		centers[carried] = _carry_spot()
	_apply_bodies()
