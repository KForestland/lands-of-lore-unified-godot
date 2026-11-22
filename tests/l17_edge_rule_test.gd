extends SceneTree
## BK01 (2026-11-09): the region-edge rule on the Subterranean Caverns. Region 1236's no-neighbour side (a boundary "wall"
## from (-4807,12,-1988) to (-4400,12,-2193), up to 52) ran straight across corridor 562: with the rule it is neither drawn
## nor collided (a ray across the wall line at walking height passes). Region 1236's own sloped floor and ceiling still lie
## over 562 (two corridor layouts at one height); the region-aware collision (act2_map REGION_COLLISION_AREAS) keeps them
## apart as the original's region-based mover does - l17_throat_walk_test walks arrival 1 to the exit pocket through it.
## The THROAT rays below are informative: cast from the arrival's active set, they see only the regions near the start.
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	if not ok: failures += 1; print("FAIL l17 edge rule: ", label)
	return ok
func _initialize() -> void: run.call_deferred()
func hit(scene: Node, from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1, [scene.player.get_rid()])
	return scene.get_world_3d().direct_space_state.intersect_ray(ray)
func run() -> void:
	set_meta("lol2_map_start_selector", 1)
	var scene = load("res://scenes/lol2/maps/L17_HC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.ready_for_review, "L17 ready"): quit(1); return
	var counts: Dictionary = scene.edge_rule_counts
	check(int(counts.get("pass_walls", 0)) > 0 and int(counts.get("walls", 0)) > int(counts.get("pass_walls", 0)), "boundary walls with a corridor beyond them are dropped, the rest stay (%s)" % str(counts))
	# Across region 1236's former wall line, from corridor 562's side (south-east) to 1236's side, at walking height.
	var wall_mid := Vector3(-4603.5, 30, -2090.5)
	var normal := Vector3(0.45, 0, 0.89)   # perpendicular to the wall line (-4807,-1988)-(-4400,-2193)
	var across: Dictionary = hit(scene, wall_mid + normal * 40.0, wall_mid - normal * 40.0)
	check(across.is_empty() or across.position.distance_to(wall_mid) > 30.0, "no collision on the dropped wall line (%s)" % str(across.get("position", "none")))
	# Informative: the throat seen from the arrival's active region set (region-aware collision; nothing near it collides yet).
	var up: Dictionary = hit(scene, Vector3(-4587, 2, -2115), Vector3(-4587, 200, -2115))
	print("THROAT ceiling above (-4587,-2115): ", up.get("position", "none"), " normal ", up.get("normal", "none"))
	check(scene.region_collision_enabled and scene.region_collision_shapes.size() > 100, "region-aware collision holds %d region shapes" % scene.region_collision_shapes.size())
	var side: Dictionary = hit(scene, Vector3(-4587, 36, -2087), Vector3(-4587, 36, -2087) + Vector3(0.3, 0, 0.95) * 60.0)
	print("THROAT ahead of (-4587,36,-2087): ", side.get("position", "none"), " normal ", side.get("normal", "none"))
	if failures == 0: print("PASS l17 edge rule: region 1236's boundary wall no longer cuts corridor 562; its overlapping layout is kept apart by the region-aware collision")
	scene.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)
