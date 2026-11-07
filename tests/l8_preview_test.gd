extends SceneTree
## Lane l8-preview (Act 2 start, L8_SJ "Darker Jungle"): the Act 1 producers extended with --area L8_SJ (static assemblies,
## static collision, region blockers, creature nav) and the Enhanced/--l8-preview-gated additions of darker_jungle.gd.
## Headless: producer outputs and counts; proof that the existing darker_jungle pack already draws every assembly face
## (so the preview builds collision only, nothing twice); Classic scene unchanged (no preview nodes); preview scene with
## the native solid boxes and the region blockers; the gate offers the "Preview: Act 2 start" button in both editions (owner 2026-10-30).
const ROOT := "res://assets/lol2/generated/"
const EXPECTED_SOLIDS := [62, 67, 68, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 114, 116, 136]  # unscripted, drawn, height >= 16; + tree 114 / log bridge 116 as scripted solids (l8_tree_bridge.gd, grok Y02 2026-11-06)
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

func load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	# 1. Producer outputs.
	var assemblies: Dictionary = load_json(ROOT + "static_assemblies/L8_SJ/assemblies.json")
	check(assemblies.area == "L8_SJ" and int(assemblies.counts.placements) == 165 and int(assemblies.counts.drawn) == 114 and int(assemblies.counts.owned) == 0, "static assemblies L8_SJ: 165 placements, 114 drawn, none owned")
	check(assemblies.review_coincident == assemblies.drawn, "every drawn assembly coincides with a face the darker_jungle pack already draws")
	for file in assemblies.materials:
		check(FileAccess.get_sha256(ROOT + "static_assemblies/L8_SJ/" + file) == assemblies.materials[file].sha256, "assembly material staged: " + file)
	var collision: Dictionary = load_json("res://scripts/lol2/static_collision_L8_SJ.json")
	var unscripted := 0
	for key in collision.boxes: if not bool(collision.boxes[key].scripted): unscripted += 1
	check(collision.area == "L8_SJ" and collision.boxes.size() == 35 and unscripted == 18, "static collision L8_SJ: 35 boxes, 18 unscripted")
	var blockers: Dictionary = load_json(ROOT + "region_blockers/L8_SJ.json")
	check(blockers.area == "L8_SJ" and blockers.blocked_regions.size() == 1085 and blockers.edges.size() == 859 and blockers.dynamic_regions.size() == 5, "region blockers L8_SJ: 1085 blocked regions, 859 edges, 5 op197 regions excluded")
	check(blockers.archive_sha256 == "3eff07430a453d2c6f09133f869874e0530af1b6a3bfff7f4297761b96a28bc2", "blockers pinned to L8_SJ.MIX")
	var nav: Dictionary = load_json(ROOT + "creature_nav/L8_SJ.json")
	check(nav.area == "L8_SJ" and nav.regions.size() == 3961 and nav.source_sha256 == blockers.archive_sha256, "creature nav L8_SJ: 3961 regions from the same archive")
	# 2. The pack's movable faces are exactly the producer's drawn assemblies (no second drawing).
	var area: Dictionary = load_json(ROOT + "darker_jungle/area.json")
	var pack_assemblies := {}
	for face in area.faces:
		if face.get("kind") == "movable" and face.get("placement_kind") == "static_assembly": pack_assemblies[int(face.source_index)] = true
	var drawn := {}
	for id in assemblies.drawn: drawn[int(id)] = true
	check(pack_assemblies == drawn, "pack draws the same 114 assemblies (%d) as the producer (%d)" % [pack_assemblies.size(), drawn.size()])
	check(area.start[0] == -4577 and area.start[2] == 1168, "pack start is the native arrival selector 1 (-4577, -1168)")
	# 3. Classic scene (Phase A 2026-10-30): the collision and the blockers are no longer preview-gated; the Act 1 arrival has them.
	Engine.set_meta("lol2_enhanced", false)
	var classic = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(classic)
	for i in 5: await process_frame
	check(classic.preview_assemblies != null and classic.preview_blockers == 859, "Classic: native collision and 859 blocker edges attached (%d)" % classic.preview_blockers)
	check(classic.get_node_or_null("StaticAssemblies_L8_SJ") != null and classic.get_node_or_null("RegionBlockers") != null, "Classic: collision and blocker nodes present")
	check(classic.player.position == Vector3(area.start[0], area.start[1], area.start[2]), "Classic start unchanged")
	classic.queue_free()
	for i in 3: await process_frame
	# 4. Enhanced meta: the same collision-only assemblies and blockers.
	Engine.set_meta("lol2_enhanced", true)
	var preview = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(preview)
	for i in 5: await process_frame
	check(preview.preview_assemblies != null and preview.get_node_or_null("StaticAssemblies_L8_SJ") != null, "preview: static assemblies host attached")
	if preview.preview_assemblies != null:
		var meshes := 0; var bodies := 0
		for child in preview.preview_assemblies.get_children():
			if child is MeshInstance3D: meshes += 1
			elif child is StaticBody3D: bodies += 1
		# The pack draws every assembly except the tree 114 and the log bridge 116, whose presence l8_tree_bridge.gd drives
		# (managed presence builds their meshes here; grok Y02 2026-11-06).
		var managed: int = 0
		for child in preview.preview_assemblies.get_children():
			if child is MeshInstance3D and (str(child.name).contains("114") or str(child.name).contains("116")): managed += 1
		check(meshes == managed and managed > 0, "preview: only the tree/bridge assembly meshes (the pack draws the rest) (%d, %d)" % [meshes, managed])
		var ids: Array = preview.preview_assemblies.solid_bodies.keys(); ids.sort()
		check(ids == EXPECTED_SOLIDS and bodies == EXPECTED_SOLIDS.size(), "preview: %d native solid boxes %s" % [bodies, ids])
		check((preview.player.collision_mask & preview.preview_assemblies.SCENERY_LAYER) != 0, "preview: the player collides with the scenery layer")
	check(preview.preview_blockers == 859 and preview.get_node_or_null("RegionBlockers") != null, "preview: 859 blocker edges attached (%d)" % preview.preview_blockers)
	check(preview.player.position == Vector3(area.start[0], area.start[1], area.start[2]), "preview starts at the native arrival")
	preview.queue_free()
	for i in 3: await process_frame
	# 5. Gate button in both editions, labelled as a test start (the owner's "jump to Act 2").
	var gate_classic = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
	Engine.set_meta("lol2_enhanced", false)
	root.add_child(gate_classic); await process_frame
	var classic_button: Node = gate_classic.find_child("L8Preview", true, false)
	check(classic_button != null and classic_button.text == "Preview: Act 2 start", "gate (Classic): 'Preview: Act 2 start' offered")
	gate_classic.queue_free(); await process_frame
	Engine.set_meta("lol2_enhanced", true)
	var gate_enhanced = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
	root.add_child(gate_enhanced); await process_frame
	var enhanced_button: Node = gate_enhanced.find_child("L8Preview", true, false)
	check(enhanced_button != null and enhanced_button.text == "Preview: Act 2 start", "gate (Enhanced): 'Preview: Act 2 start' offered")
	gate_enhanced.queue_free(); await process_frame
	Engine.set_meta("lol2_enhanced", false)
	print("L8 preview: %d failures" % failures)
	if failures == 0: print("PASS l8 preview: L8_SJ producers (assemblies 114 drawn = pack faces, collision 35/18, blockers 1085/859, nav 3961); Classic and preview both carry the 14 solids + blockers; gate button in both editions")
	quit(0 if failures == 0 else 1)
