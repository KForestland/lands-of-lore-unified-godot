extends SceneTree
## Phase A map L19_BC (lane l19-map, 2026-10-30, standing list item 4): the generic Act 2/3 map pack (tools/prepare_map_portable.py --area L19_BC),
## its per-area producers (sky, static assemblies, static collision, region blockers, creature nav), the generic host
## (act2_map.gd) and the gate's registry buttons. Headless: pack contract, producer outputs, scene state, rays, gate.
const ROOT := "res://assets/lol2/generated/"
const PACK := ROOT + "maps/L19_BC/area.json"
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
	check(area.area == "L19_BC" and area.source.sha256 == "59cd77a17e8fce0286281fdea17e134fc88436cbc0c77b1a5f4039e5edde3380", "pack pinned to L19_BC.MIX")
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
	check(area.faces.size() == 9753, "pack faces 9753 (%d)" % area.faces.size())
	check(int(kinds.get("floor", 0)) == 2859 and floorless == 0, "2859 floors = every native floor record, none floorless (%d/%d)" % [int(kinds.get("floor", 0)), floorless])
	check(int(kinds.get("ceiling", 0)) == 2849, "2849 ceilings = every primary region roofed (2841) + 8 subdivision pieces; no open sky (%d)" % int(kinds.get("ceiling", 0)))
	check(int(kinds.get("source_wall", 0)) == 3325, "3325 source walls = every wall record the original renders (%d)" % int(kinds.get("source_wall", 0)))
	check(int(kinds.get("movable", 0)) == 704 and movables == 166 and static_assemblies.size() == 103, "704 placement faces: 103 static assemblies drawn + 166 movable faces (%d/%d/%d)" % [int(kinds.get("movable", 0)), static_assemblies.size(), movables])
	check(int(kinds.get("emulated_boundary", 0)) == 16, "16 emulated boundary quads, labelled (%d)" % int(kinds.get("emulated_boundary", 0)))
	var flipped := 0
	var attached := 0
	for prop in area.props:
		if int(prop.get("frame_flags", 0)) & 0xC0: flipped += 1
		if not prop.has("record"): attached += 1
	check(area.props.size() == 244 and attached == 35 and flipped == 21, "244 prop rows: 209 rendered placements + 35 attached type-1 children; 21 row-flipped (flag 0x80) (%d/%d/%d)" % [area.props.size(), attached, flipped])
	check(area.materials.size() == 83, "83 staged materials (%d)" % area.materials.size())
	for file in area.materials.values():
		if not FileAccess.file_exists(PACK.get_base_dir() + "/" + file):
			check(false, "material image missing: " + str(file))
			break
	check(Vector3(area.start[0], area.start[1], area.start[2]) == Vector3(84, 22, 305) and int(area.start_heading_units) == 49152 and int(area.start_selector) == 1, "test start = native arrival selector 1 (84, -305, heading 49152) on floor -10 + 32 (%s)" % [area.start])
	check(area.arrivals.size() == 4 and "Birthing Chamber" in area.adjacent_labels, "the pack keeps the 4 arrival records and the adjacent-level labels")
	# 2. Per-area producers.
	check(not FileAccess.file_exists(ROOT + "map_sky/L19_BC/environment.json"), "no sky pack: the level's texture container has no panorama record (fully roofed)")
	var assemblies: Dictionary = load_json(ROOT + "static_assemblies/L19_BC/assemblies.json")
	check(int(assemblies.counts.placements) == 153 and int(assemblies.counts.drawn) == 103 and int(assemblies.counts.owned) == 0, "static assemblies: 153 placements, 103 drawn, none owned")
	check(assemblies.review_coincident == assemblies.drawn, "every drawn assembly coincides with a pack face (nothing drawn twice)")
	var drawn := {}
	for id in assemblies.drawn: drawn[int(id)] = true
	check(static_assemblies == drawn, "the pack draws the same 103 assemblies as the producer")
	var collision: Dictionary = load_json("res://scripts/lol2/static_collision_L19_BC.json")
	var unscripted := 0
	for key in collision.boxes: if not bool(collision.boxes[key].scripted): unscripted += 1
	check(collision.area == "L19_BC" and collision.boxes.size() == 4 and unscripted == 3, "static collision: 4 boxes, 3 unscripted (%d/%d)" % [collision.boxes.size(), unscripted])
	var blockers: Dictionary = load_json(ROOT + "region_blockers/L19_BC.json")
	check(blockers.area == "L19_BC" and blockers.blocked_regions.size() == 72 and blockers.edges.size() == 62 and blockers.dynamic_regions.size() == 16, "region blockers: 72 bit0 regions, 62 edges, 16 op197 regions excluded")
	check(blockers.archive_sha256 == area.source.sha256, "blockers pinned to the same archive")
	var nav: Dictionary = load_json(ROOT + "creature_nav/L19_BC.json")
	check(nav.area == "L19_BC" and nav.regions.size() == 2870, "creature nav: 2870 regions")
	# 3. Scene (Classic).
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	check(scene.area_id == "L19_BC" and scene.prop_instances == 244 and scene.prop_batches > 0 and scene.prop_placements.size() == 244, "scene: 244 batched prop instances in %d batches" % scene.prop_batches)
	var flipped_batches := 0
	var plain_batches := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("MapProps_"):
			var material: Material = child.multimesh.mesh.material
			var uv_scale: Vector2 = material.get_shader_parameter("uv_scale") if material is ShaderMaterial else Vector2(material.uv1_scale.x,material.uv1_scale.y)
			if uv_scale.x < 0 or uv_scale.y < 0: flipped_batches += 1
			else: plain_batches += 1
	check(flipped_batches > 0 and plain_batches > 0, "scene: row-flipped batches beside the plain ones (%d/%d)" % [flipped_batches, plain_batches])
	check(scene.preview_assemblies != null and scene.get_node_or_null("StaticAssemblies_L19_BC") != null, "scene: static collision host attached")
	if scene.preview_assemblies != null:
		var meshes := 0
		var bodies := 0
		for child in scene.preview_assemblies.get_children():
			if child is MeshInstance3D: meshes += 1
			elif child is StaticBody3D: bodies += 1
		check(meshes == 0 and bodies == scene.preview_assemblies.solid_bodies.size(), "scene: collision-only solids, %d boxes" % bodies)
	check(scene.preview_blockers == 62 and scene.get_node_or_null("RegionBlockers") != null, "scene: 62 blocker edges attached (%d)" % scene.preview_blockers)
	check(scene.get_node_or_null("JungleSkyEnvironment") == null, "scene: no panorama environment (authored sky fallback behind a fully roofed level)")
	check(scene.player.position == Vector3(84, 22, 305), "scene: player at the native arrival (%s)" % scene.player.position)
	check(absf(angle_difference(scene.player.rotation.y, -TAU * 49152.0 / 65536.0)) < 0.001, "scene: arrival heading 49152 -> yaw %.3f" % scene.player.rotation.y)
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
	var query := PhysicsRayQueryParameters3D.create(Vector3(84, 50, 305), Vector3(84, -300, 305))
	query.collision_mask = preload("res://scripts/lol2/region_blockers.gd").RAY_MASK
	query.exclude = [scene.player.get_rid()]  # the capsule's top sits at 46 above the floor
	var hit: Dictionary = space.intersect_ray(query)
	check(not hit.is_empty() and absf(hit.position.y + 10.0) < 1.0, "scene: floor under the arrival at -10 (%s)" % [hit.get("position", "miss")])
	scene.queue_free()
	for i in 3: await process_frame
	# 4. Gate: registry button in both editions.
	var registry: Array = preload("res://scripts/lol2/act2_map.gd").registry()
	var registered := false
	for entry in registry:
		if str(entry.area) == "L19_BC": registered = true
	check(registered, "registry lists L19_BC (any order: other lanes add rows)")
	for enhanced in [false, true]:
		Engine.set_meta("lol2_enhanced", enhanced)
		var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
		root.add_child(gate); await process_frame
		var button: Node = gate.find_child("MapPreview_L19_BC", true, false)
		check(button != null and button.text == "Preview: Belial's Chamber (L19_BC)", "gate (%s): L19_BC test-start button" % ("Enhanced" if enhanced else "Classic"))
		gate.queue_free(); await process_frame
	Engine.set_meta("lol2_enhanced", false)
	print("L19 map: %d failures" % failures)
	if failures == 0: print("PASS l19 map: pack 9753 faces (2859 floors, 2849 ceilings, 3325 source walls, 103 assemblies + 166 movables, 16 boundaries), 244 props (21 row-flipped), no panorama, 4 collision boxes, 62 blockers, nav 2870; scene hosts all of it from arrival 1; gate button in both editions")
	quit(0 if failures == 0 else 1)
