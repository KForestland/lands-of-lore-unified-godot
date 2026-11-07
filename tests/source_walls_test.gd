extends SceneTree
## Lane playtest-maps-r12q (S1 shared fixes, 2026-10-30): the original's wall records appended to the Jungle and Hive packs
## (tools/prepare_source_walls.py: drawn only, no collision), the Jungle ceilings, native bit0 region blockers in every Act 1
## area (layer 1<<9), the region-65535 placement rule of lol2/map_props and the Museum frame flips. Headless: pack contracts,
## scene attachments, no Jungle prop above the map.
const ROOT := "res://assets/lol2/generated/"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + message)

func load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	# 1. Jungle pack: appended source walls, retired spans, ceilings, span_start.
	var jungle: Dictionary = load_json(ROOT + "jungle_review/jungle.json")
	var faces: Array = jungle.faces
	var span_start := int(jungle.interior_audit.span_start)
	check(faces.size() == 11216 and span_start == 7573 and int(jungle.interior_audit.span_count) == 2903, "jungle.json: 11216 faces, spans at 7573..10475 (%d, %d)" % [faces.size(), span_start])
	var appended := 0; var ceilings := 0; var one_3065 := 0; var ceiling_4577 := false; var bad := 0
	for i in range(span_start + int(jungle.interior_audit.span_count), faces.size()):
		var face: Dictionary = faces[i]
		if face.kind == "wall" and bool(face.get("source_wall", false)):
			appended += 1
			if not face.has("material") or not jungle.materials.has(str(face.material)) or not face.has("wall_record"): bad += 1
			if int(face.region) == 3065 and int(face.edge) == 0 and int(face.surface_code) == 4: one_3065 += 1
		elif face.kind == "ceiling":
			ceilings += 1
			if int(face.region) == 4577 and str(face.material) == "657" and is_equal_approx(float(face.points[0][1]), -90.0): ceiling_4577 = true
		else: bad += 1
	check(appended == 280 and bad == 0 and one_3065 == 1, "jungle.json: 280 appended source walls, textured, incl. region 3065 edge 0 code 4 (%d, bad %d)" % [appended, bad])
	check(ceilings == 460 and ceiling_4577, "jungle.json: 460 native ceilings incl. the gorge corridor 4577 at -90 (%d)" % ceilings)
	var retired: Array = jungle.retired_static_wall_indices
	var retired_ok := retired.size() == 120
	for index in retired:
		var face: Dictionary = faces[int(index)]
		if face.kind != "wall" or face.has("material") or int(index) >= span_start + int(jungle.interior_audit.span_count): retired_ok = false
	check(retired_ok, "jungle.json: 120 retired spans, all unbound walls before the appended faces")
	check(int(jungle.source_walls.rendered) == 4571 and int(jungle.source_walls.appended) == 280, "jungle.json source_walls summary")
	# 2. Hive pack.
	var hive: Dictionary = load_json(ROOT + "hive_review/hive.json")
	var hive_appended := 0; var brazier := 0
	for face in hive.faces:
		if face.kind == "wall" and bool(face.get("source_wall", false)):
			hive_appended += 1
			if int(face.region) == 838 and int(face.edge) == 0 and int(face.wall_record) in [1609, 1610]: brazier += 1
	check(hive.faces.size() == 4305 and int(hive.interior_audit.span_start) == 3495 and hive_appended == 304 and brazier == 2 and hive.source_walls.skipped_special.size() == 15, "hive.json: 4305 faces, 304 appended source walls (15 bit-0x10 records skipped) incl. the brazier room's edge 838/0 records 1609+1610 (%d, %d)" % [hive_appended, brazier])
	for face in hive.faces:
		if face.kind == "wall" and bool(face.get("source_wall", false)) and int(face.surface_code) >= 16: check(false, "bit-0x10 record appended")
	# 4. Region blockers staged for every Act 1 area.
	var expected_edges := {"L1_DC": 12, "L3_DH": 551, "L5_HC": 68, "L7_DH": 42, "L4_HJ": 815}
	for area in expected_edges:
		var blockers: Dictionary = load_json(ROOT + "region_blockers/%s.json" % area)
		check(blockers.edges.size() == expected_edges[area], "region blockers %s: %d edges (%d)" % [area, expected_edges[area], blockers.edges.size()])
	var hive_blockers: Dictionary = load_json(ROOT + "region_blockers/L5_HC.json")
	check(1067 in hive_blockers.blocked_regions.map(func(r): return int(r)), "Hive blockers include region 1067 behind the boulder pile")
	# --open-regions 1422 (adapter, DEVIATIONS 2026-10-31): the Museum escape chamber is open; its own three edges into 1423-1425 are walls.
	var museum_blockers: Dictionary = load_json(ROOT + "region_blockers/L3_DH.json")
	check(museum_blockers.open_regions.size() == 1 and int(museum_blockers.open_regions[0]) == 1422 and not (1422 in museum_blockers.blocked_regions.map(func(r): return int(r))) and museum_blockers.edges.filter(func(e): return int(e.blocked) == 1422).is_empty() and museum_blockers.edges.filter(func(e): return int(e.region) == 1422).size() == 3, "Museum blockers: region 1422 open (no edge into it, 3 edges out of it) (%s)" % [museum_blockers.open_regions])
	# 5. Jungle props: 5830 instances, none above the map (max ceiling 400).
	var props: Dictionary = load_json(ROOT + "jungle_props/props.json")
	var instances := 0; var above := 0
	for group in props.groups:
		for row in group.instances:
			instances += 1
			if float(row[1]) > 400.0: above += 1
	check(int(props.props) == 5830 and instances == 5830 and above == 0, "jungle_props: 5830 instances, none above the map (%d, above %d)" % [instances, above])
	# 6. Scenes: blockers attached; Cave ray across the wall under the bridge; Museum flip material.
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for i in 1500:
		await process_frame
		if cave.walkthrough_ready: break
	check(cave.walkthrough_ready, "Cave ready")
	if cave.walkthrough_ready:
		# Blockers ON by default in every Act 1 host (lead 2026-10-31 blockers-on; r12r had them off outside the Jungle). Each host keeps its own flag.
		check(cave.region_blockers_attached == 12 and cave.get_node_or_null("RegionBlockers") != null, "Cave: blockers on by default, 12 edges (%d)" % cave.region_blockers_attached)
		# Jungle source walls are drawn only: no SourceWallCollision body anywhere.
	cave.queue_free()
	for i in 3: await process_frame
	var hive_scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive_scene)
	for i in 1500:
		await process_frame
		if hive_scene.ready_for_review: break
	check(hive_scene.ready_for_review and hive_scene.region_blockers_attached == 68 and hive_scene.get_node_or_null("RegionBlockers") != null, "Hive: blockers on by default, 68 edges (%d)" % hive_scene.region_blockers_attached)
	check(hive_scene.get_node_or_null("SourceWallCollision") == null, "Hive: appended source walls carry no collision body")
	hive_scene.queue_free()
	for i in 3: await process_frame
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(museum)
	for i in 1500:
		await process_frame
		if museum.ready_for_review: break
	check(museum.ready_for_review and museum.region_blockers_attached == 551 and museum.get_node_or_null("RegionBlockers") != null, "Museum: blockers on by default, 551 edges (%d)" % museum.region_blockers_attached)
	# The escape run's entry into region 1422 (native (3048, -1094), from 1021) is free; a blocker-layer ray across that edge hits nothing,
	# while the ray across the first static edge of the pack hits the blockers.
	if museum.ready_for_review and museum.get_node_or_null("RegionBlockers") != null:
		for i in 3: await physics_frame
		var layer: int = preload("res://scripts/lol2/region_blockers.gd").LAYER
		var space: PhysicsDirectSpaceState3D = museum.player.get_world_3d().direct_space_state
		var escape: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(3048, 40, 1060), Vector3(3048, 40, 1164), layer))
		check(escape.is_empty(), "Museum: the escape edge into region 1422 is open (%s)" % [escape.get("collider")])
		var edge: Dictionary = museum_blockers.edges[0]
		var mid := Vector3((float(edge.a[0]) + float(edge.b[0])) / 2.0, float(edge.floor) + 40.0, (float(edge.a[1]) + float(edge.b[1])) / 2.0)
		var inside := Vector3(float(edge.inside[0]), float(edge.floor) + 40.0, float(edge.inside[1]))
		var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(inside, mid + (mid - inside).normalized() * 8.0, layer))
		check(not wall.is_empty() and str(wall.collider.name) == "RegionBlockers", "Museum: a static blocked edge (region %d -> %d) is a wall (%s)" % [int(edge.region), int(edge.blocked), wall.get("collider")])
	var flipped: Node = museum.find_child("MuseumProp_346", true, false)
	var plain: Node = museum.find_child("MuseumProp_318", true, false)
	check(flipped != null and plain != null and flipped.material_override.uv1_scale.y == -1.0 and plain.material_override.uv1_scale.y == 1.0, "Museum: record 346 (flag 0x80) rows reversed, record 318 (flag 0) not")
	museum.queue_free()
	for i in 3: await process_frame
	var halls = load("res://scenes/lol2/dark_halls.tscn").instantiate()
	root.add_child(halls)
	for i in 1500:
		await process_frame
		if halls.ready_for_review: break
	check(halls.ready_for_review and halls.region_blockers_attached == 42 and halls.get_node_or_null("RegionBlockers") != null and halls.source_wall_kind_collides, "Dark Halls: blockers on by default, 42 edges, walls still solid (%d)" % halls.region_blockers_attached)
	halls.queue_free()
	for i in 3: await process_frame
	print("Source walls: %d failures" % failures)
	if failures == 0: print("PASS source walls: Jungle +280 walls/+460 ceilings/120 retired, Hive +304 (15 bit-0x10 skipped), blockers ON in every Act 1 host on layer 1<<9 (Museum 1422 open), 5830 Jungle props below the sky, Museum flips")
	quit(0 if failures == 0 else 1)
