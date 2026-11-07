extends SceneTree
## Phase A map L10_DC (lane l10-map, 2026-10-30): the generic Act 2/3 map pack (tools/prepare_map_portable.py --area L10_DC),
## its per-area producers (sky, static assemblies, static collision, region blockers, creature nav), the generic host
## (act2_map.gd) and the gate's registry buttons. Headless: pack contract, producer outputs, scene state, rays, gate.
const ROOT := "res://assets/lol2/generated/"
const PACK := ROOT + "maps/L10_DC/area.json"
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
	check(area.area == "L10_DC" and area.source.sha256 == "543c86c4fdd425cac166d9a1d371aa856b7070d4fded983a8733c473e48341f9", "pack pinned to L10_DC.MIX")
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
	check(area.faces.size() == 17416, "pack faces 17416 (%d)" % area.faces.size())
	check(int(kinds.get("floor", 0)) == 4314 and floorless == 0, "4314 floors = every native floor record, none floorless (%d/%d)" % [int(kinds.get("floor", 0)), floorless])
	check(int(kinds.get("ceiling", 0)) == 3121, "3121 ceilings = every region with a native ceiling selector; 1171 open to the panorama (%d)" % int(kinds.get("ceiling", 0)))
	check(int(kinds.get("source_wall", 0)) == 6883, "6883 source walls = every wall record the original renders (%d)" % int(kinds.get("source_wall", 0)))
	check(int(kinds.get("movable", 0)) == 3086 and movables == 472 and static_assemblies.size() == 220, "3086 placement faces: 220 static assemblies drawn + 472 movable faces (%d/%d/%d)" % [int(kinds.get("movable", 0)), static_assemblies.size(), movables])
	check(int(kinds.get("emulated_boundary", 0)) == 12, "12 emulated boundary quads, labelled (%d)" % int(kinds.get("emulated_boundary", 0)))
	var flipped := 0
	var attached := 0
	for prop in area.props:
		if int(prop.get("frame_flags", 0)) & 0x40: flipped += 1
		if not prop.has("record"): attached += 1
	check(area.props.size() == 771 and attached == 326 and flipped == 10, "771 prop rows: 445 rendered placements + 326 attached type-1 children; 10 column-flipped (%d/%d/%d)" % [area.props.size(), attached, flipped])
	check(area.materials.size() == 326, "326 staged materials (%d)" % area.materials.size())
	for file in area.materials.values():
		if not FileAccess.file_exists(PACK.get_base_dir() + "/" + file):
			check(false, "material image missing: " + str(file))
			break
	check(Vector3(area.start[0], area.start[1], area.start[2]) == Vector3(-542, 32, -856) and int(area.start_heading_units) == 24758 and int(area.start_selector) == 2, "test start = native arrival selector 2 (-542, 856, heading 24758) + 32 (%s)" % [area.start])
	check(area.arrivals.size() == 3 and "Teleport to Dracoid Ruins" in area.adjacent_labels, "the pack keeps the 3 arrival records and the adjacent-level labels")
	# 2. Per-area producers.
	var sky: Dictionary = load_json(ROOT + "map_sky/L10_DC/environment.json")
	check(int(sky.panorama.vertical_origin) == 50 and sky.panorama.pixels_sha256 == "4be1bd69bd7cb1b662e1a5700134b17634f548b7447b3c3780adb8d4299e3d20", "sky pack: original L10_DC panorama, vertical origin 50")
	check(FileAccess.file_exists(ROOT + "map_sky/L10_DC/panorama.png") and FileAccess.file_exists(ROOT + "map_sky/L10_DC/panorama_indices.png"), "sky images staged")
	var assemblies: Dictionary = load_json(ROOT + "static_assemblies/L10_DC/assemblies.json")
	check(int(assemblies.counts.placements) == 274 and int(assemblies.counts.drawn) == 220 and int(assemblies.counts.owned) == 0, "static assemblies: 274 placements, 220 drawn, none owned")
	check(assemblies.review_coincident == assemblies.drawn, "every drawn assembly coincides with a pack face (nothing drawn twice)")
	var drawn := {}
	for id in assemblies.drawn: drawn[int(id)] = true
	check(static_assemblies == drawn, "the pack draws the same 220 assemblies as the producer")
	var collision: Dictionary = load_json("res://scripts/lol2/static_collision_L10_DC.json")
	var unscripted := 0
	for key in collision.boxes: if not bool(collision.boxes[key].scripted): unscripted += 1
	check(collision.area == "L10_DC" and collision.boxes.size() == 152 and unscripted == 65, "static collision: 152 boxes, 65 unscripted (%d/%d)" % [collision.boxes.size(), unscripted])
	var blockers: Dictionary = load_json(ROOT + "region_blockers/L10_DC.json")
	check(blockers.area == "L10_DC" and blockers.blocked_regions.size() == 1043 and blockers.edges.size() == 766 and blockers.dynamic_regions.size() == 10, "region blockers: 1043 bit0 regions, 766 edges, 10 op197 regions excluded")
	check(blockers.archive_sha256 == area.source.sha256, "blockers pinned to the same archive")
	var nav: Dictionary = load_json(ROOT + "creature_nav/L10_DC.json")
	check(nav.area == "L10_DC" and nav.regions.size() == 4320, "creature nav: 4320 regions")
	# 3. Scene (Classic).
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	check(scene.area_id == "L10_DC" and scene.prop_instances == 771 and scene.prop_batches > 0 and scene.prop_placements.size() == 771, "scene: 771 batched prop instances in %d batches" % scene.prop_batches)
	var flipped_batches := 0
	var plain_batches := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("MapProps_"):
			var material: Material = child.multimesh.mesh.material
			var scale_x: float = material.get_shader_parameter("uv_scale").x if material is ShaderMaterial else material.uv1_scale.x
			if scale_x < 0: flipped_batches += 1
			else: plain_batches += 1
	check(flipped_batches > 0 and plain_batches > 0, "scene: flipped and plain prop batches (%d/%d)" % [flipped_batches, plain_batches])
	check(scene.preview_assemblies != null and scene.get_node_or_null("StaticAssemblies_L10_DC") != null, "scene: static collision host attached")
	if scene.preview_assemblies != null:
		var meshes := 0
		var bodies := 0
		for child in scene.preview_assemblies.get_children():
			if child is MeshInstance3D: meshes += 1
			elif child is StaticBody3D: bodies += 1
		# Barrel and puddle states now use this renderer; generic pack faces must stay unduplicated.
		var managed_meshes := 0
		for id in scene.preview_assemblies.stateful_meshes:
			check(int(id) in [61,62,176,177,165,166,167,168,169,170,171,172,173], "scene: only barrel/puddle owners add assembly meshes")
			managed_meshes += scene.preview_assemblies.stateful_meshes[id].size()
		check(meshes == managed_meshes and bodies == scene.preview_assemblies.solid_bodies.size() and bodies > 0, "scene: managed barrel/puddle meshes and %d solid boxes" % bodies)
	check(scene.preview_blockers == 766 and scene.get_node_or_null("RegionBlockers") != null, "scene: 766 blocker edges attached (%d)" % scene.preview_blockers)
	check(scene.get_node_or_null("JungleSkyEnvironment") != null, "scene: the panorama sky environment")
	check(scene.player.position == Vector3(-542, 32, -856), "scene: player at the native arrival (%s)" % scene.player.position)
	check(is_equal_approx(scene.player.rotation.y, -TAU * 24758.0 / 65536.0), "scene: arrival heading 24758 -> yaw %.3f" % scene.player.rotation.y)
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
	var query := PhysicsRayQueryParameters3D.create(Vector3(-542, 60, -856), Vector3(-542, -200, -856))
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
		if str(entry.area) == "L10_DC": registered = true
	check(registered, "registry lists L10_DC (any order: other lanes add rows)")
	for enhanced in [false, true]:
		Engine.set_meta("lol2_enhanced", enhanced)
		var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
		root.add_child(gate); await process_frame
		var button: Node = gate.find_child("MapPreview_L10_DC", true, false)
		check(button != null and button.text == "Preview: Dracoid Cemetary (L10_DC)", "gate (%s): L10_DC test-start button" % ("Enhanced" if enhanced else "Classic"))
		gate.queue_free(); await process_frame
	Engine.set_meta("lol2_enhanced", false)
	print("L10 map: %d failures" % failures)
	if failures == 0: print("PASS l10 map: pack 17416 faces (4314 floors, 3121 ceilings, 6883 source walls, 220 assemblies + 472 movables, 12 boundaries), 771 props (10 flipped), sky origin 50, 152 collision boxes, 766 blockers, nav 4320; scene hosts all of it from arrival 2; gate button in both editions")
	quit(0 if failures == 0 else 1)
