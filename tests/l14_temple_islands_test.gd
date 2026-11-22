extends SceneTree
## L14 Huline Temple visibility islands (Fable TEMPLE-ISLANDS 2026-11-07): the pack's render_sector names the original's room
## of every static face; islands() maps every nav region that has a face to exactly one room, the opening rule closes the
## edges between stacked rooms, and the view walk from the owner's F10 poses never draws the room stacked under or over
## the one the player stands in (r16 21-05-00 hangings room over the -80 room; r14 18-01-10 garden room over the -100
## outdoor sector; r14 18-01-36 hall over the -80 corridor). Headless: no scene, the walk runs on the data alone.
const Vis = preload("res://scripts/lol2/region_visibility.gd")
class Host extends Node3D:
	var portal_regions: Array = []
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL temple islands: ", message)
func _initialize() -> void: run.call_deferred()
func islands_seen(vis: Node, seen: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for r in seen: out[int(vis.cluster_of.get(r, -1))] = true
	return out
func run() -> void:
	var nav: Array = Vis.load_regions("L14_HT")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/maps/L14_HT/area.json"))
	check(nav.size() == 4275, "L14 nav has 4275 regions: %d" % nav.size())
	var faces: Array = pack.faces
	var islands: Dictionary = Vis.islands(nav, faces)
	var rooms: Dictionary = {}
	for r in islands: rooms[int(islands[r])] = true
	check(islands.size() >= 4200 and islands.size() <= nav.size(), "regions with a room: %d" % islands.size())
	check(rooms.size() >= 200 and rooms.size() <= 300, "rooms: %d" % rooms.size())
	# No region is claimed by two rooms (every face of a region names the same render_sector).
	var conflicts := 0
	for face in faces:
		if face.get("region") == null or int(face.get("render_sector", -1)) < 0: continue
		if int(islands.get(int(face.region), -1)) != int(face.render_sector): conflicts += 1
	check(conflicts == 0, "faces whose room differs from their region's room: %d" % conflicts)
	var host := Host.new(); host.portal_regions = nav
	root.add_child(host)
	var vis: Node = Vis.new()
	host.add_child(vis)
	var potential: Dictionary = Vis.load_potential("L14_HT")
	check(potential.size() == 254, "native potential sets staged for 254 rooms: %d" % potential.size())
	var links := 0
	for key in potential: links += potential[key].size()
	check(links == 3041, "native potential links: %d" % links)
	# The stacked rooms of the owner's poses are not in their room's native set either.
	check(not potential.get(int(islands[830]), {}).has(int(islands[3237])), "hangings room 28: the -80 room under it is outside the native set")
	check(not potential.get(int(islands[918]), {}).has(int(islands[630])), "garden room 31: the -100 outdoor sector is outside the native set")
	# Native region heights for the sky ceilings (island_sky_ceilings.gd): every region, and the roofless regions (no ceiling
	# face in the pack) still have a native ceiling (hangings-room region 830: 125, three-door-room region 1483: 470).
	var native: Dictionary = Vis.load_native("L14_HT")
	var heights: Array = native.get("region_ceiling", [])
	check(heights.size() == nav.size(), "native ceiling heights staged for every region: %d" % heights.size())
	var roofed: Dictionary = {}
	for face in faces:
		if face.get("kind") == "ceiling" and face.get("region") != null: roofed[int(face.region)] = true
	var roofless := 0
	for r in nav.size(): if not roofed.has(r): roofless += 1
	check(roofless == 344, "roofless regions (sky through the native ceiling): %d" % roofless)
	check(heights.size() > 1483 and int(heights[830]) == 125 and int(heights[1483]) == 470, "native ceilings of regions 830/1483: %s/%s" % [str(heights[830]) if heights.size() > 830 else "-", str(heights[1483]) if heights.size() > 1483 else "-"])
	vis.setup(host, "L14_HT", nav, islands, {}, faces, potential)
	check(vis.closed_edges >= 40 and vis.closed_edges <= 400, "closed edges between rooms: %d" % vis.closed_edges)
	# Same-room edges are never closed.
	var same_closed := 0
	for r in nav.size():
		for e in vis.edges[r]:
			if e.size() > 3 and not bool(e[3]) and int(islands.get(r, -1)) == int(islands.get(int(e[0]), -2)): same_closed += 1
	check(same_closed == 0, "closed edges inside one room: %d" % same_closed)
	var camera := Camera3D.new(); camera.fov = 75.0
	host.add_child(camera)
	# [name, position (Godot x, eye y, z), yaw, room the player is in, stacked room that must stay hidden]
	var poses: Array = [
		["r16 21-05-00 hangings room", Vector3(2430.2, 42.0, -3458.3), 0.8748, 830, 3237],
		["r14 18-01-10 garden room", Vector3(2625.3, 42.0, -2698.8), 0.348, 918, 630],
		["r14 18-01-36 hall", Vector3(2876.3, 42.0, -3361.9), -0.538, 21, 3889],
		["r14 18-10-50 three-door room", Vector3(-310.2, 232.0, -2304.3), 3.08, 1485, -1]]
	var drawn: Dictionary = {}
	for pose in poses:
		camera.position = pose[1]; camera.rotation = Vector3(0, float(pose[2]), 0)
		var seen: Dictionary = vis.compute(camera)
		var rooms_seen: Dictionary = islands_seen(vis, seen)
		var own := int(islands.get(int(pose[3]), -1))
		check(seen.has(int(pose[3])) and rooms_seen.has(own), "%s: starts in region %d (room %d)" % [pose[0], pose[3], own])
		if int(pose[4]) >= 0:
			var stacked := int(islands.get(int(pose[4]), -1))
			check(stacked != own and not rooms_seen.has(stacked), "%s: stacked room %d (region %d) stays hidden" % [pose[0], stacked, pose[4]])
		check(rooms_seen.size() <= 12, "%s: rooms drawn %d" % [pose[0], rooms_seen.size()])
		var listed: Array = rooms_seen.keys(); listed.sort()
		drawn[pose[0]] = listed
		print("POSE ", pose[0], " regions ", seen.size(), " rooms ", listed)
	# A deterministic sweep: from 200 region centroids and four headings, every drawn room is the camera's own or in its
	# native potential set (the bound), and the bound did keep rooms out somewhere (it is not a no-op).
	var kept_out := 0
	var violations := 0
	var sweep := 0
	for i in range(0, nav.size(), nav.size() / 200):
		var poly: Array = nav[i][0]
		var centre := Vector2.ZERO
		for p in poly: centre += Vector2(float(p[0]), float(p[1]))
		centre /= float(poly.size())
		for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
			camera.position = Vector3(centre.x, float(nav[i][1]) + 42.0, centre.y); camera.rotation = Vector3(0, yaw, 0)
			var seen: Dictionary = vis.compute(camera)
			if seen.is_empty(): continue
			sweep += 1
			kept_out += vis.bounded
			var own := int(islands.get(int(vis.last_start), -1))
			for room in islands_seen(vis, seen):
				if int(room) != own and not potential.get(own, {}).has(int(room)): violations += 1
	check(sweep >= 600, "sweep poses: %d" % sweep)
	check(violations == 0, "rooms drawn outside the native potential set: %d" % violations)
	check(kept_out > 0, "the native bound kept out regions somewhere in the sweep: %d" % kept_out)
	print("sweep %d poses, %d regions kept out by the native bound" % [sweep, kept_out])
	# The old 24-region clusters mixed rooms: the owner's hangings-room pose drew pieces of other rooms.
	var clusters: Dictionary = Vis.clusters(nav)
	var mixed := 0
	var by_cluster: Dictionary = {}
	for r in clusters:
		var c := int(clusters[r])
		if not by_cluster.has(c): by_cluster[c] = {}
		by_cluster[c][int(islands.get(r, -1))] = true
	for c in by_cluster: if by_cluster[c].size() > 1: mixed += 1
	check(mixed > 0, "clusters spanning more than one room (the leak this replaces): %d" % mixed)
	print("clusters %d, mixed %d" % [by_cluster.size(), mixed])
	if failures == 0: print("PASS L14 temple islands: %d regions in %d rooms, %d closed edges, native potential sets bound the walk, %d roofless regions get the sky through their native ceiling, owner poses never draw a stacked room" % [islands.size(), rooms.size(), vis.closed_edges, roofless])
	quit(0 if failures == 0 else 1)
