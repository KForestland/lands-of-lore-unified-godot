extends SceneTree
## Phase A map L13_RC (lane l13-map, 2026-10-30, standing list item 2): the generic Act 2/3 map pack (tools/prepare_map_portable.py --area L13_RC),
## its per-area producers (sky, static assemblies, static collision, region blockers, creature nav), the generic host
## (act2_map.gd) and the gate's registry buttons. Headless: pack contract, producer outputs, scene state, rays, gate.
const ROOT := "res://assets/lol2/generated/"
const PACK := ROOT + "maps/L13_RC/area.json"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

func load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	# 1. Pack contract (two producer runs byte-identical, see the handoff).
	var area: Dictionary = load_json(PACK)
	check(area.area == "L13_RC" and area.source.sha256 == "b9d79292e7dd6fc2eba972e55628ee05e671a4d814de8b291310d540b3f742b9", "pack pinned to L13_RC.MIX")
	var kinds := {}
	var floorless := 0
	var static_assemblies := {}
	var movables := 0
	for face in area.faces:
		kinds[face.kind] = int(kinds.get(face.kind, 0)) + 1
		if face.get("floorless", false): floorless += 1
		if face.kind == "movable":
			if face.get("placement_kind") == "static_assembly": static_assemblies[int(face.source_index)] = true
			else: movables += 1
	check(area.faces.size() == 5230, "pack faces 5230 (%d)" % area.faces.size())
	check(int(kinds.get("floor", 0)) == 1381 and floorless == 0, "1381 floors = every native floor record, none floorless (%d/%d)" % [int(kinds.get("floor", 0)), floorless])
	check(int(kinds.get("ceiling", 0)) == 1391, "1391 ceiling faces (every region with a native ceiling selector, subdivision pieces included) (%d)" % int(kinds.get("ceiling", 0)))
	check(int(kinds.get("source_wall", 0)) == 1755, "1755 source walls = every wall record the original renders (%d)" % int(kinds.get("source_wall", 0)))
	check(int(kinds.get("movable", 0)) == 699 and movables == 466 and static_assemblies.size() == 59, "699 placement faces: 59 static assemblies drawn + 466 movable faces (%d/%d/%d)" % [int(kinds.get("movable", 0)), static_assemblies.size(), movables])
	check(int(kinds.get("emulated_boundary", 0)) == 4, "4 emulated boundary quads, labelled (%d)" % int(kinds.get("emulated_boundary", 0)))
	var flipped := 0
	var attached := 0
	for prop in area.props:
		if int(prop.get("frame_flags", 0)) & 0x80: flipped += 1
		if not prop.has("record"): attached += 1
	check(area.props.size() == 364 and attached == 0 and flipped == 2, "364 prop rows: every rendered placement, no type-1 children in this level; 2 row-flipped (flag 0x80) (%d/%d/%d)" % [area.props.size(), attached, flipped])
	check(area.materials.size() == 112, "112 staged materials (%d)" % area.materials.size())
	for file in area.materials.values():
		if not FileAccess.file_exists(PACK.get_base_dir() + "/" + file):
			check(false, "material image missing: " + str(file))
			break
	check(Vector3(area.start[0], area.start[1], area.start[2]) == Vector3(-3344, 32, 6564) and int(area.start_heading_units) == 28089 and int(area.start_selector) == 0, "test start = native arrival selector 0 (-3344, -6564, heading 28089) + 32 (%s)" % [area.start])
	check(area.arrivals.size() == 4 and "The Great Forge" in area.adjacent_labels, "the pack keeps the 4 arrival records and the adjacent-level labels")
	# 2. Per-area producers.
	var sky: Dictionary = load_json(ROOT + "map_sky/L13_RC/environment.json")
	check(int(sky.panorama.vertical_origin) == 0 and sky.panorama.pixels_sha256 == "52bcb877e9781cea561306b592fefb3a1b1bbec39f7ee2eccdfcceabf38ea8c2", "sky pack: original L13_RC panorama (the L16_CA backgrnd image), vertical origin 0")
	check(FileAccess.file_exists(ROOT + "map_sky/L13_RC/panorama.png") and FileAccess.file_exists(ROOT + "map_sky/L13_RC/panorama_indices.png"), "sky images staged")
	var assemblies: Dictionary = load_json(ROOT + "static_assemblies/L13_RC/assemblies.json")
	check(int(assemblies.counts.placements) == 109 and int(assemblies.counts.drawn) == 59 and int(assemblies.counts.owned) == 0, "static assemblies: 109 placements, 59 drawn, none owned")
	check(assemblies.review_coincident == assemblies.drawn, "every drawn assembly coincides with a pack face (nothing drawn twice)")
	var drawn := {}
	for id in assemblies.drawn: drawn[int(id)] = true
	check(static_assemblies == drawn, "the pack draws the same 59 assemblies as the producer")
	var collision: Dictionary = load_json("res://scripts/lol2/static_collision_L13_RC.json")
	var unscripted := 0
	for key in collision.boxes: if not bool(collision.boxes[key].scripted): unscripted += 1
	check(collision.area == "L13_RC" and collision.boxes.size() == 43 and unscripted == 0, "static collision: 43 boxes, all scripted (owners host them later) (%d/%d)" % [collision.boxes.size(), unscripted])
	var blockers: Dictionary = load_json(ROOT + "region_blockers/L13_RC.json")
	check(blockers.area == "L13_RC" and blockers.blocked_regions.size() == 37 and blockers.edges.size() == 37 and blockers.dynamic_regions.size() == 10, "region blockers: 37 bit0 regions, 37 edges, 10 op197 regions excluded")
	check(blockers.archive_sha256 == area.source.sha256, "blockers pinned to the same archive")
	var nav: Dictionary = load_json(ROOT + "creature_nav/L13_RC.json")
	check(nav.area == "L13_RC" and nav.regions.size() == 1449, "creature nav: 1449 regions")
	# 3. Scene (Classic).
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/maps/L13_RC.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	check(scene.area_id == "L13_RC" and scene.prop_instances == 364 and scene.prop_batches > 0 and scene.prop_placements.size() == 364, "scene: 364 batched prop instances in %d batches" % scene.prop_batches)
	var flipped_batches := 0
	var plain_batches := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("MapProps_"):
			var material: Material = child.multimesh.mesh.material
			var uv_scale: Vector2 = material.get_shader_parameter("uv_scale") if material is ShaderMaterial else Vector2(material.uv1_scale.x,material.uv1_scale.y)
			if uv_scale.y < 0: flipped_batches += 1
			else: plain_batches += 1
	check(flipped_batches > 0 and plain_batches > 0, "scene: row-flipped and plain prop batches (%d/%d)" % [flipped_batches, plain_batches])
	check(scene.preview_assemblies != null and scene.get_node_or_null("StaticAssemblies_L13_RC") != null, "scene: static collision host attached")
	if scene.preview_assemblies != null:
		var meshes := 0
		var bodies := 0
		for child in scene.preview_assemblies.get_children():
			if child is MeshInstance3D: meshes += 1
			elif child is StaticBody3D: bodies += 1
		check(meshes == 0 and bodies == 0 and scene.preview_assemblies.solid_bodies.is_empty(), "scene: every L13 solid is scripted, so no unowned box is built (%d)" % bodies)
	check(scene.preview_blockers == 37 and scene.get_node_or_null("RegionBlockers") != null, "scene: 37 blocker edges attached (%d)" % scene.preview_blockers)
	check(scene.get_node_or_null("JungleSkyEnvironment") != null, "scene: the panorama sky environment")
	check(scene.player.position == Vector3(-3344, 32, 6564), "scene: player at the native arrival (%s)" % scene.player.position)
	check(is_equal_approx(scene.player.rotation.y, -TAU * 28089.0 / 65536.0), "scene: arrival heading 28089 -> yaw %.3f" % scene.player.rotation.y)
	# Source walls are drawn only (S1 rule; kind "source_wall" since 2026-10-31): the shell's collision triangles are bounded by the
	# non-wall faces (two per quad), so a wall with collision would push the count past the bound.
	var shell_triangles := 0
	for child in scene.get_children():
		if child is StaticBody3D and child.get_child_count() > 0 and child.get_child(0) is CollisionShape3D and child.get_child(0).shape is ConcavePolygonShape3D:
			shell_triangles = (child.get_child(0).shape as ConcavePolygonShape3D).get_faces().size() / 3
			break
	var non_wall_faces: int = area.faces.size() - int(kinds.get("source_wall", 0))
	check(shell_triangles > 0 and shell_triangles <= 2 * non_wall_faces, "scene: shell collision %d triangles <= 2 x %d non-wall faces (source walls drawn only)" % [shell_triangles, non_wall_faces])
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(-3344, 60, 6564), Vector3(-3344, -200, 6564))
	query.collision_mask = preload("res://scripts/lol2/region_blockers.gd").RAY_MASK
	query.exclude = [scene.player.get_rid()]  # the capsule's top sits at 46 above the floor
	var hit: Dictionary = space.intersect_ray(query)
	check(not hit.is_empty() and absf(hit.position.y) < 1.0, "scene: floor under the arrival at 0 (%s)" % [hit.get("position", "miss")])
	scene.queue_free()
	for i in 3: await process_frame
	# 4. Gate: registry button in both editions.
	var registry: Array = preload("res://scripts/lol2/act2_map.gd").registry()
	var registered := false
	for entry in registry:
		if str(entry.area) == "L13_RC": registered = true
	check(registered, "registry lists L13_RC (any order: other lanes add rows)")
	for enhanced in [false, true]:
		Engine.set_meta("lol2_enhanced", enhanced)
		var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
		root.add_child(gate); await process_frame
		var button: Node = gate.find_child("MapPreview_L13_RC", true, false)
		check(button != null and button.text == "Preview: L13_RC (Ruloi caverns)", "gate (%s): L13_RC test-start button" % ("Enhanced" if enhanced else "Classic"))
		gate.queue_free(); await process_frame
	Engine.set_meta("lol2_enhanced", false)
	print("L13 map: %d failures" % failures)
	if failures == 0: print("PASS l13 map: pack 5230 faces (1381 floors, 1391 ceilings, 1755 source walls, 59 assemblies + 466 movables, 4 boundaries), 364 props (2 row-flipped), sky origin 0, 43 scripted collision boxes, 37 blockers, nav 1449; scene hosts all of it from arrival 0; gate button in both editions")
	quit(0 if failures == 0 else 1)
