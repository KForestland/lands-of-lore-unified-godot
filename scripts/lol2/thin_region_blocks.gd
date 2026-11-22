extends StaticBody3D
## Thin hanging regions no body can stand in, solid to the player (owner F10 2026-11-15 03-27-37, L10 yard region 1029).
## Data: thin_region_blocks/AREA.json from tools/prepare_thin_region_blocks.py, pinned to the pack it was read from; with any
## other pack nothing is built. One convex prism per floor polygon of each region, from just above the walkable floor under
## it to its ceiling, on the region-blocker layer (player only: rays and creatures keep their masks). A body already inside a
## prism (an old save, the owner's own) is lifted out sideways onto that floor, once, on the nearest free side.
const LAYER := 1 << 9
const ROOT := "res://scripts/lol2/thin_region_blocks/"
const LIFT := 1.0
var player: CharacterBody3D
var prisms: Array = []  # [PackedVector2Array outline, bottom, top]
var lifted := 0

static func path_for(area: String) -> String: return ROOT + area + ".json"

static func attach(host: Node3D, body: CharacterBody3D, area: String, pack_path: String) -> Node:
	if not FileAccess.file_exists(path_for(area)): return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(area)))
	if not data is Dictionary or str(data.get("area")) != area: push_error("Thin region blocks: bad data for " + area); return null
	if str(data.get("pack_sha256")) != FileAccess.get_sha256(pack_path):
		push_warning("Thin region blocks: %s was made from another pack; not built" % area)
		return null
	var node: StaticBody3D = load("res://scripts/lol2/thin_region_blocks.gd").new()
	node.name = "ThinRegionBlocks"
	node.collision_layer = LAYER
	node.collision_mask = 0
	node.player = body
	for row in data.regions:
		for polygon in row.polygons:
			var outline := PackedVector2Array()
			for p in polygon: outline.append(Vector2(float(p[0]), float(p[1])))
			var bottom := float(row.bottom) + LIFT
			var top := float(row.ceiling)
			var points := PackedVector3Array()
			for v in outline:
				points.append(Vector3(v.x, bottom, v.y)); points.append(Vector3(v.x, top, v.y))
			var shape := ConvexPolygonShape3D.new(); shape.points = points
			var holder := CollisionShape3D.new(); holder.shape = shape
			node.add_child(holder)
			node.prisms.append([outline, bottom, top])
	host.add_child(node)
	return node

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player): return
	var at := player.global_position
	var feet := at.y - preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for prism in prisms:
		var outline: PackedVector2Array = prism[0]
		if feet >= float(prism[2]) or feet + 46.0 <= float(prism[1]) - LIFT: continue
		if not Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), outline): continue
		_lift_out(outline, float(prism[1]) - LIFT)
		return

## Out past the nearest edge of the prism's outline by the body radius, standing on the floor the region hangs over; edges are
## tried nearest first and the first spot where the body overlaps nothing is taken (the yard side, not into the wall).
func _lift_out(outline: PackedVector2Array, ground: float) -> void:
	var here := Vector2(player.global_position.x, player.global_position.z)
	var centre := Vector2.ZERO
	for v in outline: centre += v
	centre /= outline.size()
	var spots: Array = []
	for i in outline.size():
		var a := outline[i]; var b := outline[(i + 1) % outline.size()]
		var q := Geometry2D.get_closest_point_to_segment(here, a, b)
		var normal := Vector2(b.y - a.y, a.x - b.x).normalized()
		if normal.dot(q - centre) < 0.0: normal = -normal
		spots.append([here.distance_to(q), q + normal * 25.0])
	spots.sort_custom(func(x, y): return x[0] < y[0])
	var foot := preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for spot in spots:
		var to: Vector2 = spot[1]
		var xf := Transform3D(player.global_transform.basis, Vector3(to.x, ground + foot + 0.5, to.y))
		if _free(xf):
			player.global_transform = xf
			player.velocity = Vector3.ZERO
			lifted += 1
			return
	push_warning("Thin region blocks: no free side beside the prism the body is in")

func _free(xf: Transform3D) -> bool:
	var space := player.get_world_3d().direct_space_state
	for owner_id in player.get_shape_owners():
		for k in player.shape_owner_get_shape_count(owner_id):
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = player.shape_owner_get_shape(owner_id, k)
			q.transform = xf * player.shape_owner_get_transform(owner_id)
			q.collision_mask = player.collision_mask
			q.exclude = [player.get_rid()]
			if not space.intersect_shape(q, 1).is_empty(): return false
	return true
