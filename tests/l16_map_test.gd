extends SceneTree
## Phase A map L16_CA (lane l16-map, 2026-10-30, standing list item 3): the generic Act 2/3 map pack (tools/prepare_map_portable.py --area L16_CA),
## its per-area producers (sky, static assemblies, static collision, region blockers, creature nav), the generic host
## (act2_map.gd) and the gate's registry buttons. Headless: pack contract, producer outputs, scene state, rays, gate.
const ROOT := "res://assets/lol2/generated/"
const PACK := ROOT + "maps/L16_CA/area.json"
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
	check(area.area == "L16_CA" and area.source.sha256 == "810d39ae20a980c4b912fda9dbb05db7917b879fbfcc7cdf4a9f91d26707d2a4", "pack pinned to L16_CA.MIX")
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
	check(area.faces.size() == 31391, "pack faces 31391 (%d)" % area.faces.size())
	check(int(kinds.get("floor", 0)) == 10580 and floorless == 0, "10580 floors = every native floor record, none floorless (%d/%d)" % [int(kinds.get("floor", 0)), floorless])
	check(int(kinds.get("ceiling", 0)) == 6173, "6173 ceilings = every region with a native ceiling selector; the rest open to the panorama (%d)" % int(kinds.get("ceiling", 0)))
	check(int(kinds.get("source_wall", 0)) == 12316, "12316 source walls = every wall record the original renders (%d)" % int(kinds.get("source_wall", 0)))
	check(int(kinds.get("movable", 0)) == 2254 and movables == 842 and static_assemblies.size() == 248, "2254 placement faces: 248 static assemblies drawn + 842 movable faces (%d/%d/%d)" % [int(kinds.get("movable", 0)), static_assemblies.size(), movables])
	check(int(kinds.get("emulated_boundary", 0)) == 68, "68 emulated boundary quads, labelled (%d)" % int(kinds.get("emulated_boundary", 0)))
	var flipped := 0
	var attached := 0
	for prop in area.props:
		if int(prop.get("frame_flags", 0)) & 0xC0: flipped += 1
		if not prop.has("record"): attached += 1
	check(area.props.size() == 599 and attached == 35 and flipped == 1, "599 prop rows: 564 rendered placements + 35 attached type-1 children; one row flipped both ways (flags 0xC0) (%d/%d/%d)" % [area.props.size(), attached, flipped])
	check(area.materials.size() == 427, "427 staged materials (%d)" % area.materials.size())
	for file in area.materials.values():
		if not FileAccess.file_exists(PACK.get_base_dir() + "/" + file):
			check(false, "material image missing: " + str(file))
			break
	# Owner 2026-10-31: the preview starts where the player arrives from the Huline temple (L14_HT s1 group 9210 `020100001c30` = level 16,
	# selector 1), arrival 1 (-3860, 1341, heading 1, region 137, floor 0); until then selector 3 (beside the L17 exit) was the adapter.
	check(Vector3(area.start[0], area.start[1], area.start[2]) == Vector3(-3860, 32, -1341) and int(area.start_heading_units) == 1 and int(area.start_selector) == 1 and str(area.start_witness).contains("9210"), "test start = native arrival selector 1 (-3860, 1341, heading 1), the L14_HT arrival, on floor 0 + 32 (%s)" % [area.start])
	check(area.arrivals.size() == 4 and "Hive Caverns" in area.adjacent_labels, "the pack keeps the 4 arrival records and the adjacent-level labels")
	# 2. Per-area producers.
	var sky: Dictionary = load_json(ROOT + "map_sky/L16_CA/environment.json")
	check(int(sky.panorama.vertical_origin) == 100 and sky.panorama.pixels_sha256 == "a4205f489d68f2c0d40174ce342a167d82aa4856f5276c7b5007ee78ba35aaec", "sky pack: original L16_CA panorama (backgrn1.pcx), vertical origin 100")
	check(FileAccess.file_exists(ROOT + "map_sky/L16_CA/panorama.png") and FileAccess.file_exists(ROOT + "map_sky/L16_CA/panorama_indices.png"), "sky images staged")
	var assemblies: Dictionary = load_json(ROOT + "static_assemblies/L16_CA/assemblies.json")
	check(int(assemblies.counts.placements) == 326 and int(assemblies.counts.drawn) == 248 and int(assemblies.counts.owned) == 0, "static assemblies: 326 placements, 248 drawn, none owned")
	check(assemblies.review_coincident == assemblies.drawn, "every drawn assembly coincides with a pack face (nothing drawn twice)")
	var drawn := {}
	for id in assemblies.drawn: drawn[int(id)] = true
	check(static_assemblies == drawn, "the pack draws the same 248 assemblies as the producer")
	var collision: Dictionary = load_json("res://scripts/lol2/static_collision_L16_CA.json")
	var unscripted := 0
	for key in collision.boxes: if not bool(collision.boxes[key].scripted): unscripted += 1
	check(collision.area == "L16_CA" and collision.boxes.size() == 80 and unscripted == 49, "static collision: 80 boxes, 49 unscripted (%d/%d)" % [collision.boxes.size(), unscripted])
	var blockers: Dictionary = load_json(ROOT + "region_blockers/L16_CA.json")
	check(blockers.area == "L16_CA" and blockers.blocked_regions.size() == 162 and blockers.edges.size() == 171 and blockers.dynamic_regions.size() == 1, "region blockers: 162 bit0 regions, 171 edges, 1 op197 region excluded")
	check(blockers.archive_sha256 == area.source.sha256, "blockers pinned to the same archive")
	var nav: Dictionary = load_json(ROOT + "creature_nav/L16_CA.json")
	check(nav.area == "L16_CA" and nav.regions.size() == 10582, "creature nav: 10582 regions")
	# 3. Scene (Classic).
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	check(scene.area_id == "L16_CA" and scene.prop_instances == 599 and scene.prop_batches > 0 and scene.prop_placements.size() == 599, "scene: 599 batched prop instances in %d batches" % scene.prop_batches)
	var flipped_batches := 0
	var plain_batches := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("MapProps_"):
			var material: Material = child.multimesh.mesh.material
			var uv_scale: Vector2 = material.get_shader_parameter("uv_scale") if material is ShaderMaterial else Vector2(material.uv1_scale.x,material.uv1_scale.y)
			if uv_scale.x < 0 or uv_scale.y < 0: flipped_batches += 1
			else: plain_batches += 1
	check(flipped_batches == 1 and plain_batches > 0, "scene: one flipped batch beside the plain ones (%d/%d)" % [flipped_batches, plain_batches])
	check(scene.preview_assemblies != null and scene.get_node_or_null("StaticAssemblies_L16_CA") != null, "scene: static collision host attached")
	if scene.preview_assemblies != null:
		var meshes := 0
		var bodies := 0
		for child in scene.preview_assemblies.get_children():
			if child is MeshInstance3D: meshes += 1
			elif child is StaticBody3D: bodies += 1
		check(meshes == 0 and bodies == scene.preview_assemblies.solid_bodies.size() and bodies > 0, "scene: collision-only solids, %d boxes" % bodies)
	check(scene.preview_blockers == 171 and scene.get_node_or_null("RegionBlockers") != null, "scene: 171 blocker edges attached (%d)" % scene.preview_blockers)
	check(scene.get_node_or_null("JungleSkyEnvironment") != null, "scene: the panorama sky environment")
	check(scene.player.position == Vector3(-3860, 32, -1341), "scene: player at the native arrival 1 from the Huline temple (%s)" % scene.player.position)
	check(absf(angle_difference(scene.player.rotation.y, -TAU * 1.0 / 65536.0)) < 0.001, "scene: arrival heading 1 -> yaw %.3f" % scene.player.rotation.y)
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
	var query := PhysicsRayQueryParameters3D.create(Vector3(-7820, -470, 10696), Vector3(-7820, -800, 10696))
	query.collision_mask = preload("res://scripts/lol2/region_blockers.gd").RAY_MASK
	query.exclude = [scene.player.get_rid()]  # the capsule's top sits at 46 above the floor
	var hit: Dictionary = space.intersect_ray(query)
	check(not hit.is_empty() and absf(hit.position.y + 530.0) < 1.0, "scene: floor under the arrival at -530 (%s)" % [hit.get("position", "miss")])
	scene.queue_free()
	for i in 3: await process_frame
	# 4. Gate: registry button in both editions.
	var registry: Array = preload("res://scripts/lol2/act2_map.gd").registry()
	var registered := false
	for entry in registry:
		if str(entry.area) == "L16_CA": registered = true
	check(registered, "registry lists L16_CA (any order: other lanes add rows)")
	for enhanced in [false, true]:
		Engine.set_meta("lol2_enhanced", enhanced)
		var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
		root.add_child(gate); await process_frame
		var button: Node = gate.find_child("MapPreview_L16_CA", true, false)
		check(button != null and button.text == "Preview: City of the Ancients (L16_CA)", "gate (%s): L16_CA test-start button" % ("Enhanced" if enhanced else "Classic"))
		gate.queue_free(); await process_frame
	Engine.set_meta("lol2_enhanced", false)
	print("L16 map: %d failures" % failures)
	if failures == 0: print("PASS l16 map: pack 31391 faces (10580 floors, 6173 ceilings, 12316 source walls, 248 assemblies + 842 movables, 68 boundaries), 599 props (1 flipped both ways), sky origin 100, 80 collision boxes, 171 blockers, nav 10582; scene hosts all of it from arrival 3; gate button in both editions")
	quit(0 if failures == 0 else 1)
