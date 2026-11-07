extends SceneTree
## Every Jungle walk-route fixture (tools/build_jungle_blocker_routes.py) stays out of the native player-impassable
## regions and is walkable against the real blocker collision (region_blockers.gd attach on L4_HJ): a human capsule
## (radius 15, height 46) is moved with move_and_slide from each route's first region toward every waypoint in turn,
## colliding only with the blocker layer, and must reach each within 3 units. Terrain, gates and actors are covered by
## the walk tests and campaign legs that use these fixtures. The owner's roots-forest report #17 (r12c, 17:58) stood
## inside bit0 region 3555: walking from a passable neighbour toward it stops at the shared edge. The Jungle host has
## the blockers switched on.
const Blockers := preload("res://scripts/lol2/region_blockers.gd")
const ROUTES := {
	"earned_jungle_hive_walk_route": [""],
	"act_one_departure_route": [""],
	"dark_halls_entry6_monastery_route": [""],
	"hive_quest_walk_routes": ["jungle_to_village", "village_to_followup", "followup_to_tavern", "tavern_to_monastery"],
	"hive_flute_return_routes": ["monastery_to_hive"],
	"hive_rune_return_routes": ["jungle_to_monastery"],
	"magic_shop_walk": ["to_shop", "to_monastery"],
	"weapon_shop_walk": ["to_shop", "to_monastery"],
	"chief_hut_walk_routes": ["inner_gate_to_pool", "pool_to_village"],
	"chut_pool_route": ["chut_to_pool"],
}
var nav: Array
var blocked := {}
var body: CharacterBody3D
var host: Node3D
var blockers: StaticBody3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_blocker_routes: ", message); quit(1)

func centre(region: int) -> Vector2:
	var c := Vector2.ZERO
	for p in nav[region][0]: c += Vector2(p[0], p[1])
	return c / 4.0
func floor_of(region: int) -> float: return float(nav[region][1])

## Moves the capsule toward `target` at walking speed; height follows the source floor of the current leg (the blocker
## faces span floor-64 .. ceiling+1024, so only the plane matters). Static collision only, so the 1/60 s steps run
## back to back instead of one per real physics frame. Returns the distance left.
func walk_to(target: Vector2, height: float, frames := 2400) -> float:
	for i in frames:
		var p := Vector2(body.global_position.x, body.global_position.z)
		var offset := target - p
		if offset.length() < 3.0: return offset.length()
		body.global_position.y = height
		var step := offset.normalized() * minf(80.0, offset.length() * 60.0)
		body.velocity = Vector3(step.x, 0, step.y)
		body.move_and_slide()
		if i % 2000 == 1999: await process_frame
	return (target - Vector2(body.global_position.x, body.global_position.z)).length()

func run() -> void:
	# Instancing the host leaves its _init-created helpers orphaned in a bare SceneTree; read the declared default.
	if not "\nvar region_blockers_enabled := true\n" in FileAccess.get_file_as_string("res://scripts/lol2/jungle_walkthrough.gd"): return fail("Jungle host has the native region blockers switched off")
	nav = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/creature_nav/L4_HJ.json")).regions
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Blockers.path_for("L4_HJ")))
	for id in data.blocked_regions: blocked[int(id)] = true
	host = Node3D.new(); root.add_child(host)
	body = CharacterBody3D.new()
	var shape := CapsuleShape3D.new(); shape.radius = 15.0; shape.height = 46.0
	var collider := CollisionShape3D.new(); collider.shape = shape; body.add_child(collider)
	body.collision_layer = 0; body.collision_mask = 0
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	host.add_child(body)
	if Blockers.attach(host, body, "L4_HJ") <= 0: return fail("No blocker edges attached")
	blockers = host.get_node("RegionBlockers")
	if body.collision_mask != Blockers.LAYER: return fail("Capsule must collide with the blocker layer only")
	var total := 0
	for file in ROUTES:
		var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json" % file))
		for key in ROUTES[file]:
			var name: String = file if key == "" else "%s.%s" % [file, key]
			var route: Dictionary = all if key == "" else all[key]
			var regions: Array = route.regions.map(func(n): return int(n))
			for id in regions:
				if blocked.has(id): return fail("%s enters native impassable region %d" % [name, id])
			body.global_position = Vector3(centre(regions[0]).x, floor_of(regions[0]) + 30.0, centre(regions[0]).y)
			for i in 2: await physics_frame
			for i in route.points.size():
				var leg := maxf(floor_of(regions[mini(i, regions.size() - 1)]), floor_of(regions[mini(i + 1, regions.size() - 1)]))
				var target := Vector2(route.points[i][0], route.points[i][1])
				var left := await walk_to(target, leg + 30.0)
				if left >= 3.0: return fail("%s blocked at waypoint %d (region %d) %.1f short at %s" % [name, i, regions[mini(i, regions.size() - 1)], left, body.global_position])
				if blockers.inside_blocked(): return fail("%s stood inside a blocked region at waypoint %d" % [name, i])
			total += 1
			print("route %s: %d regions, %d waypoints walked against the blockers" % [name, regions.size(), route.points.size()])
	# Owner report #17 (r12c 17:58, roots forest): region 3555 is impassable; from its passable neighbour the walk stops.
	if not blocked.has(3555): return fail("Region 3555 is not impassable in the source flags")
	var edge: Dictionary = {}
	for e in data.edges:
		if int(e.blocked) == 3555: edge = e; break
	if edge.is_empty(): return fail("No open edge into region 3555")
	var from := Vector2(edge.inside[0], edge.inside[1])
	body.global_position = Vector3(from.x, floor_of(int(edge.region)) + 30.0, from.y)
	for i in 2: await physics_frame
	var left := await walk_to(centre(3555), floor_of(int(edge.region)) + 30.0, 600)
	if left < 3.0 or blockers.inside_blocked(): return fail("Walked into impassable region 3555 (report #17)")
	print("PASS jungle_blocker_routes: %d Jungle routes walkable against the native blockers; region 3555 refused (%.1f short)" % [total, left])
	host.free()
	quit(0)
