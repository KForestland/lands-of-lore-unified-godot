extends SceneTree
## L10 finer room grouping for drawing (lead 2026-11-14): L10 draws by the original's rooms (render_sector of every static
## face, region_visibility islands) bounded by the native potential sets (scripts/lol2/sector_potential/L10_DC.json,
## tools/prepare_sector_potential.py), as L14 does, instead of 24-region clusters that mix rooms. L10 keeps its sky (no
## black void or ceiling sheets: act2_map ISLAND_SKY_AREAS is L14 only). Headless: the walk runs on the data alone.
const Vis = preload("res://scripts/lol2/region_visibility.gd")
class Host extends Node3D:
	var portal_regions: Array = []
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL l10 islands: ", message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var nav: Array = Vis.load_regions("L10_DC")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/maps/L10_DC/area.json"))
	var faces: Array = pack.faces
	var islands: Dictionary = Vis.islands(nav, faces)
	var rooms: Dictionary = {}
	for r in islands: rooms[int(islands[r])] = true
	var conflicts := 0
	for face in faces:
		if face.get("region") == null or int(face.get("render_sector", -1)) < 0: continue
		if int(islands.get(int(face.region), -1)) != int(face.render_sector): conflicts += 1
	check(conflicts == 0, "faces whose room differs from their region's room: %d" % conflicts)
	var potential: Dictionary = Vis.load_potential("L10_DC")
	check(potential.size() == 893, "native potential sets for 893 rooms: %d" % potential.size())
	var links := 0
	for key in potential: links += potential[key].size()
	check(links == 25353, "native potential links: %d" % links)
	var host := Host.new(); host.portal_regions = nav
	root.add_child(host)
	var vis: Node = Vis.new()
	host.add_child(vis)
	vis.setup(host, "L10_DC", nav, islands, {}, faces, potential)
	var camera := Camera3D.new(); camera.fov = 75.0
	host.add_child(camera)
	var kept_out := 0; var violations := 0; var sweep := 0
	for i in range(0, nav.size(), nav.size() / 200):
		var poly: Array = nav[i][0]
		if poly.size() < 3: continue
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
			var drawn: Dictionary = {}
			for r in seen: drawn[int(vis.cluster_of.get(r, -1))] = true
			for room in drawn:
				if int(room) >= 0 and int(room) != own and own >= 0 and not potential.get(own, {}).has(int(room)): violations += 1
	check(sweep >= 400, "sweep poses: %d" % sweep)
	check(violations == 0, "rooms drawn outside the native potential set: %d" % violations)
	check(kept_out > 0, "the native bound kept out regions somewhere: %d" % kept_out)
	var clusters: Dictionary = Vis.clusters(nav)
	var by_cluster: Dictionary = {}
	for r in clusters:
		var c := int(clusters[r])
		if not by_cluster.has(c): by_cluster[c] = {}
		by_cluster[c][int(islands.get(r, -1))] = true
	var mixed := 0
	for c in by_cluster: if by_cluster[c].size() > 1: mixed += 1
	print("L10 rooms %d, regions with a room %d, closed edges %d, sweep %d, kept out %d, old clusters %d mixed %d" % [rooms.size(), islands.size(), vis.closed_edges, sweep, kept_out, by_cluster.size(), mixed])
	check(mixed > 0, "old clusters spanning more than one room: %d" % mixed)
	if failures == 0: print("PASS L10 islands: %d regions in %d rooms, native potential sets bound the walk (%d sweep poses, 0 outside), %d of %d old clusters mixed rooms" % [islands.size(), rooms.size(), sweep, mixed, by_cluster.size()])
	quit(0 if failures == 0 else 1)
