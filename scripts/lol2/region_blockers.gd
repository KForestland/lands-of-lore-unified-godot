extends StaticBody3D
## Native player-impassable regions (region word +0x1C bit0; B0D98/AFF85 refuse player movers): invisible walls on
## every open edge from a passable region into a blocked one (tools/prepare_region_blockers.py). They stop the player
## walking or jumping in. A player already inside a blocked region (an old save) has the layer switched off until they
## are out again, so they can always leave. Own physics layer (1<<9), so aim and line-of-sight rays (layer 1 or RAY_MASK)
## and creatures are unaffected.
## Regions opcode 197 toggles (pack dynamic_*; arms 0-5 clear/set bit 0 natively) are not in the static set. A native
## script host binder (act2_progression.gd) calls enable_dynamic() to build their edges from the data's initial bit 0 and
## set_region_blocked() on every 0x22d0c:N bit_0x1c_0x01 write the host commits; without a binder the static set stands alone.
## Own layer bit (not the static_assemblies SCENERY_LAYER 1<<8, which reach rays may want to hit): rays that keep the default
## mask ignore the blockers with RAY_MASK (the Museum aim/reach rays); layer-1 rays never see them.
const LAYER := 1 << 9
const RAY_MASK := 4294966783  # every layer but LAYER
const HEADROOM := 1024.0
const CELL := 256.0
## Portal clearance (2026-10-31, the Museum region-1422 opening): the native mover is a point that crosses a shared region
## edge anywhere along it, so the 24-unit opening between the corners of bit0 regions 1423 and 1424 is passable natively;
## the port's player is a capsule (player_form_body.gd radius 15 / 23 / 8) that two zero-thickness walls 24 units apart
## stop. A PORTAL CORNER is a point where two walls of the SAME blocked region meet with DIFFERENT passable regions on their
## far sides (a passable-to-passable boundary leaves the corner). Each such corner is chamfered by the player's current
## body radius plus a margin: both walls are shortened along themselves by that amount and a third wall closes the cut, so
## the capsule centre can reach the native edge line of the portal while the blocked region stays closed. Corners of one
## passable region (pillars) and wall continuations between different blocked regions keep their corner. The chamfer is
## rebuilt when the player's body radius changes (form change). A capsule centre may stand inside the cut triangle (less
## than `clearance` deep inside the blocked outline), which the inside test below tolerates. Logged as an adapter in DEVIATIONS.
const CLEARANCE_MARGIN := 1.0
var clearance := 0.0
var static_edges: Array = []
var static_shape: CollisionShape3D = null
var chamfers := 0
var player: CollisionObject3D
var origin := Vector3.ZERO
## Grid cell -> [outline (PackedVector2Array), floor, ceiling, dynamic region id or -1] of the blocked regions overlapping it.
var cells: Dictionary = {}
## Dynamic (opcode-197) regions: id -> blocked (bool), from the pack's dynamic_initial until the host writes bit 0.
var dynamic_state: Dictionary = {}
var dynamic_edges: Array = []
var dynamic_enabled := false
var dynamic_active_edges := 0
var dynamic_shape: CollisionShape3D = null
var _dynamic_outlines: Dictionary = {}
var _dynamic_heights: Dictionary = {}

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player): return
	var wanted := player_radius() + CLEARANCE_MARGIN
	if absf(wanted - clearance) > 0.01: rebuild_static(wanted)
	var p := Vector2(player.global_position.x - origin.x, player.global_position.z - origin.z)
	var height := player.global_position.y - origin.y
	var inside := false
	# Already inside (layer off): stay off until the centre leaves the outline entirely, or the walls would close on a player
	# walking out within `clearance` of the edge (r12w jungle_region_blockers_test). Entering needs more than `clearance` depth.
	var depth := 0.0 if player.collision_mask & LAYER == 0 else clearance
	# Stacked regions share outlines: the player counts as inside only between that region's floor and ceiling.
	for row in cells.get(Vector2i(floori(p.x / CELL), floori(p.y / CELL)), []):
		if int(row[3]) >= 0 and not bool(dynamic_state.get(int(row[3]), false)): continue
		if height >= float(row[1]) - 8.0 and height <= float(row[2]) + 64.0 and Geometry2D.is_point_in_polygon(p, row[0]) and _boundary_distance(p, row[0]) > depth:
			inside = true; break
	if inside: player.collision_mask &= ~LAYER
	else: player.collision_mask |= LAYER

func inside_blocked() -> bool: return is_instance_valid(player) and player.collision_mask & LAYER == 0

## The player's body radius (first capsule / cylinder / sphere collision shape), or 0 when none is found.
func player_radius() -> float:
	if not is_instance_valid(player): return 0.0
	for child in player.get_children():
		if child is CollisionShape3D and child.shape != null:
			var shape: Shape3D = child.shape
			if shape is CapsuleShape3D or shape is CylinderShape3D or shape is SphereShape3D: return float(shape.radius)
	return 0.0

## Rebuilds the static wall shape with every free wall end recessed by `new_clearance` (see the header).
func rebuild_static(new_clearance: float) -> void:
	clearance = new_clearance
	var faces := PackedVector3Array()
	chamfers = 0
	for edge in recessed_edges(static_edges, static_edges + dynamic_edges, clearance):
		if edge.get("chamfer", false): chamfers += 1
		_append_edge(faces, edge, origin)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	static_shape.shape = shape
	static_shape.disabled = faces.is_empty()
	if dynamic_enabled: _rebuild_dynamic()

## Copies of `edges` with every portal corner chamfered by `amount` (see the header): a corner is a point shared by exactly
## two edges of `all_edges` with the same `blocked` region and different `region`; both edges retreat along themselves by
## min(amount, 45 % of their length) and a closing edge joins the two retreated points. Returns the edited copies of
## `edges` plus the closing edges that belong to them (their keys copied from the first edge).
static func recessed_edges(edges: Array, all_edges: Array, amount: float) -> Array:
	if amount <= 0.0: return edges
	var at_corner := {}
	for edge in all_edges:
		for key in [_corner_key(edge.a), _corner_key(edge.b)]:
			if not at_corner.has(key): at_corner[key] = []
			at_corner[key].append(edge)
	var cuts := {}  # corner key -> true when it is a portal corner
	for key in at_corner:
		var pair: Array = at_corner[key]
		if pair.size() == 2 and int(pair[0].blocked) == int(pair[1].blocked) and int(pair[0].region) != int(pair[1].region): cuts[key] = true
	var out := []
	var retreated := {}  # corner key -> [points] for the closing edges
	for edge in edges:
		var a := Vector2(edge.a[0], edge.a[1])
		var b := Vector2(edge.b[0], edge.b[1])
		var length := a.distance_to(b)
		if length < 0.001: out.append(edge); continue
		var step := minf(amount, length * 0.45)
		var direction := (b - a) / length
		var copy: Dictionary = edge.duplicate()
		for end_key in [[_corner_key(edge.a), true], [_corner_key(edge.b), false]]:
			if not cuts.has(end_key[0]): continue
			var moved: Vector2 = a + direction * step if end_key[1] else b - direction * step
			if end_key[1]: a = moved
			else: b = moved
			if not retreated.has(end_key[0]): retreated[end_key[0]] = []
			retreated[end_key[0]].append([moved, copy])
		copy.a = [a.x, a.y]; copy.b = [b.x, b.y]
		out.append(copy)
	for key in retreated:
		var points: Array = retreated[key]
		if points.size() != 2: continue
		var closing: Dictionary = points[0][1].duplicate()
		closing.a = [points[0][0].x, points[0][0].y]
		closing.b = [points[1][0].x, points[1][0].y]
		closing.floor = minf(float(points[0][1].floor), float(points[1][1].floor))
		closing.ceiling = maxf(float(points[0][1].ceiling), float(points[1][1].ceiling))
		closing.chamfer = true
		out.append(closing)
	return out

## Distance from `p` to the nearest side of `outline`.
static func _boundary_distance(p: Vector2, outline: PackedVector2Array) -> float:
	var best := INF
	for i in outline.size():
		var q := Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % outline.size()])
		best = minf(best, p.distance_to(q))
	return best

static func _corner_key(point: Array) -> Vector2i: return Vector2i(roundi(float(point[0]) * 2.0), roundi(float(point[1]) * 2.0))

## Builds the edges of the dynamic regions from the pack's initial bit 0 (a binder's call). Returns the region count.
func enable_dynamic() -> int:
	if dynamic_enabled: return dynamic_state.size()
	dynamic_enabled = true
	for key in _dynamic_outlines:
		var outline := PackedVector2Array()
		for point in _dynamic_outlines[key]: outline.append(Vector2(point[0], point[1]))
		_add_cells(outline, _dynamic_heights[key][0], _dynamic_heights[key][1], int(key))
	_rebuild_dynamic()
	return dynamic_state.size()

func is_region_blocked(region: int) -> bool: return bool(dynamic_state.get(region, false))

## The host committed bit 0 of region N's word +0x1C (opcode 197 arms 0-5): rebuilds the dynamic edges. False when N is
## not a dynamic region of this pack (a static region's bit the producer did not see any opcode 197 touch).
func set_region_blocked(region: int, blocked: bool) -> bool:
	if not dynamic_state.has(region): return false
	if bool(dynamic_state[region]) == blocked and dynamic_enabled: return true
	dynamic_state[region] = blocked
	if dynamic_enabled: _rebuild_dynamic()
	return true

func _edge_active(edge: Dictionary) -> bool:
	var from_dynamic := int(edge.get("from_dynamic", -1))
	var to_dynamic := int(edge.get("to_dynamic", -1))
	if from_dynamic >= 0 and bool(dynamic_state.get(from_dynamic, false)): return false
	if to_dynamic >= 0 and not bool(dynamic_state.get(to_dynamic, false)): return false
	return true

func _rebuild_dynamic() -> void:
	var faces := PackedVector3Array()
	dynamic_active_edges = 0
	for edge in recessed_edges(dynamic_edges, static_edges + dynamic_edges, clearance):
		if not _edge_active(edge): continue
		dynamic_active_edges += 1
		_append_edge(faces, edge, origin)
	if dynamic_shape == null:
		dynamic_shape = CollisionShape3D.new()
		dynamic_shape.name = "DynamicEdges"
		add_child(dynamic_shape)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	dynamic_shape.shape = shape
	dynamic_shape.disabled = faces.is_empty()

func _add_cells(outline: PackedVector2Array, floor_height: float, ceiling_height: float, region: int) -> void:
	var box := Rect2(outline[0], Vector2.ZERO)
	for point in outline: box = box.expand(point)
	for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
		for y in range(floori(box.position.y / CELL), floori(box.end.y / CELL) + 1):
			var cell := Vector2i(x, y)
			if not cells.has(cell): cells[cell] = []
			cells[cell].append([outline, floor_height, ceiling_height, region])

static func _append_edge(faces: PackedVector3Array, edge: Dictionary, origin: Vector3) -> void:
	var a := Vector3(edge.a[0], 0, edge.a[1]) + origin
	var b := Vector3(edge.b[0], 0, edge.b[1]) + origin
	var low := float(edge.floor) + origin.y - float(edge.get("footroom", 64.0))
	var high := float(edge.ceiling) + origin.y + float(edge.get("headroom", HEADROOM))
	var quad := [Vector3(a.x, low, a.z), Vector3(b.x, low, b.z), Vector3(b.x, high, b.z), Vector3(a.x, high, a.z)]
	for i in [0, 1, 2, 0, 2, 3]: faces.append(quad[i])

static func path_for(area: String) -> String: return "res://assets/lol2/generated/region_blockers/%s.json" % area

## Builds the blockers under `host` and lets `player` collide with them. Returns the static edge count (0 when not prepared).
static func attach(host: Node3D, player: CollisionObject3D, area: String, origin := Vector3.ZERO) -> int:
	if not FileAccess.file_exists(path_for(area)): return 0
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path_for(area)))
	var body: StaticBody3D = load("res://scripts/lol2/region_blockers.gd").new()
	body.name = "RegionBlockers"
	body.collision_layer = LAYER
	body.collision_mask = 0
	body.player = player
	body.origin = origin
	for key in data.blocked_outlines:
		var outline := PackedVector2Array()
		for point in data.blocked_outlines[key]: outline.append(Vector2(point[0], point[1]))
		#0284: ground strip2417 lies below original tree-room floor220. Its
		# outdoor ceiling1500 must not classify an upper-room player as inside it.
		var ceiling:float=float(data.blocked_heights[key][1])
		if area=="L8_SJ" and key=="2417":ceiling=156.0 # Existing inside test adds64.
		body._add_cells(outline, data.blocked_heights[key][0], ceiling, -1)
	# Version 2 packs: the dynamic regions, kept until a binder enables them.
	for key in data.get("dynamic_initial", {}):
		body.dynamic_state[int(key)] = bool(data.dynamic_initial[key])
	body.dynamic_edges = data.get("dynamic_edges", [])
	body._dynamic_outlines = data.get("dynamic_outlines", {})
	body._dynamic_heights = data.get("dynamic_heights", {})
	body.static_edges = data.edges
	if area=="L8_SJ":
		for edge in body.static_edges:
			if int(edge.get("blocked",-1))==2417:
				edge.ceiling=220.0;edge["headroom"]=0.0 # Original upper floor; lower strip stays blocked.
	# Cemetery catacombs lie below walkable surface regions. Their walls must end
	# at the source ceiling instead of projecting through the upper floor.
	if area == "L10_DC":
		for edge in body.static_edges + body.dynamic_edges:
			edge["footroom"] = 0.0
			if float(edge.ceiling) < 0.0: edge["headroom"] = 0.0
	body.static_shape = CollisionShape3D.new()
	body.static_shape.name = "StaticEdges"
	body.add_child(body.static_shape)
	body.rebuild_static(body.player_radius() + CLEARANCE_MARGIN)
	host.add_child(body)
	player.collision_mask |= LAYER
	return data.edges.size()
