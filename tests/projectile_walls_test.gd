extends SceneTree
## Original-bug row 9 (misclipped plasma bolts), map side (2026-10-31): the Act 2/3 packs' source walls are drawn only for movement
## but form a "ProjectileWalls" body on PROJECTILE_WALL_LAYER. Headless on L10_DC: the body exists with two triangles per source
## wall, a ray carrying the layer stops at a wall the shell ray flies through, no mover carries the layer, and an Act 1 scene
## (no kind "source_wall" faces) builds no such body.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var Review = preload("res://scripts/lol2/jungle_review.gd")
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/maps/L10_DC/area.json"))
	var walls := 0
	for face in pack.faces: if face.kind == "source_wall": walls += 1
	var body: StaticBody3D = scene.get_node_or_null("ProjectileWalls")
	check(body != null and body.collision_layer == Review.PROJECTILE_WALL_LAYER and body.collision_mask == 0, "L10: ProjectileWalls body on layer 1<<10, mask 0")
	var triangles: int = scene.projectile_wall_triangles
	check(triangles == 2 * walls and walls == 6883, "L10: two triangles per source wall (%d / %d walls)" % [triangles, walls])
	check((scene.player.collision_mask & Review.PROJECTILE_WALL_LAYER) == 0, "the player never collides with projectile walls")
	# A wall of the arrival region: region 65's edge faces. Cast from the arrival through its nearest source wall.
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var from := Vector3(-542, 40, -856)
	var nearest := Vector3.INF
	for face in pack.faces:
		if face.kind != "source_wall": continue
		var centre := Vector3.ZERO
		for p in face.points: centre += Vector3(p[0], p[1], p[2])
		centre /= face.points.size()
		if centre.distance_to(from) < nearest.distance_to(from): nearest = centre
	var to := from + (nearest - from).normalized() * (nearest.distance_to(from) + 40.0)
	var wall_ray := PhysicsRayQueryParameters3D.create(from, to, Review.PROJECTILE_WALL_LAYER, [scene.player.get_rid()])
	var hit: Dictionary = space.intersect_ray(wall_ray)
	check(not hit.is_empty() and hit.collider == body, "a ray carrying the layer stops at the nearest source wall (%s)" % [hit.get("position", "miss")])
	var shell_ray := PhysicsRayQueryParameters3D.create(from, to, 1, [scene.player.get_rid()])
	var shell_hit: Dictionary = space.intersect_ray(shell_ray)
	check(shell_hit.is_empty() or shell_hit.collider != body, "the shell ray (mask 1) does not see the projectile walls")
	scene.queue_free(); await process_frame
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	for i in 5: await process_frame
	check(jungle.get_node_or_null("ProjectileWalls") == null and jungle.projectile_wall_triangles == 0, "Act 1 Jungle: no projectile walls body (its appended walls stay as before)")
	jungle.queue_free(); await process_frame
	print("Projectile walls: %d failures" % failures)
	if failures == 0: print("PASS projectile walls: L10 body on layer 1<<10 with %d triangles, layer ray stops at a wall, shell ray passes, player and Act 1 untouched" % triangles)
	quit(0 if failures == 0 else 1)
