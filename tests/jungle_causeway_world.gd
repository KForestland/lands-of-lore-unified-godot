extends RefCounted
## Live-node readout of the Jungle causeway (shared by the causeway live test and its save/reload pair): floor heights
## by layer-1 ray, the wall sets, controls 61/62/84 from their own meshes plus the 84 panel by ray, creature refusal by
## layer-11 rays, the player mask, and the eight props from their nodes.
const STANDING := {"collapsed": false, "4448": -114.0, "4435": -114.0, "4445": -114.0, "after": false, "before": 1, "61": false, "62": false, "84": true,
	"84solid": true, "creatures": [false, false, false], "player_free": true}
const FALLEN := {"collapsed": true, "4448": -200.0, "4435": -200.0, "4445": -134.0, "after": true, "before": 0, "61": true, "62": true, "84": false,
	"84solid": false, "creatures": [true, true, true], "player_free": true}

static func _blocked(scene: Node, a: Vector3, b: Vector3, mask: int) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(a, b, mask, [scene.player.get_rid()])
	return not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func _ground(scene: Node, region: int) -> float:
	var face: Dictionary = scene.causeway.src.floors[str(region)].initial
	var c := Vector3.ZERO
	for p in face.points: c += Vector3(p[0], 0, p[2])
	c /= face.points.size()
	var ray := PhysicsRayQueryParameters3D.create(Vector3(c.x, 300, c.z), Vector3(c.x, -600, c.z), 1, [scene.player.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
	return INF if hit.is_empty() else snappedf(hit.position.y, 0.5)

static func _barrier_hit(scene: Node, id: int) -> bool:
	for row in scene.causeway.src.creature_regions:
		if int(row.id) != id: continue
		var a := Vector2(row.polygon[0][0], row.polygon[0][1]); var b := Vector2(row.polygon[1][0], row.polygon[1][1])
		var m := (a + b) / 2.0; var n := Vector2(-(b - a).y, (b - a).x).normalized() * 20.0
		var y := (float(row.floor) + float(row.ceiling)) / 2.0
		return _blocked(scene, Vector3(m.x + n.x, y, m.y + n.y), Vector3(m.x - n.x, y, m.y - n.y), 1 << 10)
	return false

## Props as drawn: [visible, x, y, z] per record.
static func props(scene: Node) -> Dictionary:
	var out := {}
	for id in scene.causeway.props:
		var node: MeshInstance3D = scene.causeway.props[id]
		out[str(id)] = [node.is_visible_in_tree(), roundi(node.global_position.x), roundi(node.global_position.y), roundi(node.global_position.z)]
	return out

## The props the source expects for a standing or collapsed causeway.
static func expected_props(scene: Node, collapsed: bool) -> Dictionary:
	var out := {}
	for row in scene.causeway.src.props:
		var moved: bool = collapsed and str(row.action) == "move"
		var p: Array = row.target if moved else row.position
		# Native op18 0x0a85 is a teleport that keeps the prop's own height (CAUSEWAY_OP18_FLAGS_CHECK.md).
		out[str(int(row.record))] = [not (collapsed and str(row.action) == "unlink"), int(p[0]), int(row.position[1]), int(p[2])]
	return out

static func read(scene: Node) -> Dictionary:
	var a = scene.static_assemblies
	var drawn := {}
	for id in [61, 62, 84]:
		var meshes: Array = a.stateful_meshes.get(id, [])
		drawn[str(id)] = not meshes.is_empty() and meshes.all(func(m): return m.is_visible_in_tree())
		if meshes.is_empty() or drawn[str(id)] != a.is_present(id): drawn[str(id)] = "mismatch"
	return {"collapsed": scene.causeway.collapsed(), "4448": _ground(scene, 4448), "4435": _ground(scene, 4435), "4445": _ground(scene, 4445),
		"after": scene.causeway.walls_after.visible, "before": scene.causeway.walls_before.collision_layer,
		"61": drawn["61"], "62": drawn["62"], "84": drawn["84"],
		"84solid": _blocked(scene, Vector3(5780, -84, -3769), Vector3(5850, -84, -3769), a.SCENERY_LAYER),
		"creatures": [_barrier_hit(scene, 4429), _barrier_hit(scene, 4448), _barrier_hit(scene, 4447)],
		"player_free": (scene.player.collision_mask & (1 << 10)) == 0}

## Errors in the full readout against standing (false) or collapsed (true); empty when it matches.
static func compare(scene: Node, collapsed: bool) -> String:
	var w := read(scene)
	if w != (FALLEN if collapsed else STANDING): return "causeway %s" % w
	var p := props(scene)
	if p != expected_props(scene, collapsed): return "props %s" % p
	return ""
