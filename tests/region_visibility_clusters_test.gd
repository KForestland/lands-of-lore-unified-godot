extends SceneTree
## Portal-visibility clusters (Fable MAPFIX 2026-11-08): a nav region without a polygon (the producer's floor subdivisions,
## stair steps) has no edges, so a cluster of its own was never reached and its floor strip never drawn (owner r17
## 17-55-17: the sky's nadir through the missing step under the player in L10). Such regions stay out of the clusters and
## are drawn like region-less faces. Headless, data only.
const Vis = preload("res://scripts/lol2/region_visibility.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL clusters: ", message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var expected := {"L10_DC": 28, "L5_HC": 283, "L13_RC": 110}
	for area in expected:
		var nav: Array = Vis.load_regions(area)
		if nav.is_empty(): check(false, area + " nav missing"); continue
		var empty: Array = []
		for r in nav.size(): if (nav[r][0] as Array).is_empty(): empty.append(r)
		check(empty.size() == int(expected[area]), "%s polygon-less regions: %d" % [area, empty.size()])
		var clusters: Dictionary = Vis.clusters(nav)
		var clustered := 0
		for r in empty: if clusters.has(r): clustered += 1
		check(clustered == 0, "%s polygon-less regions given a cluster: %d" % [area, clustered])
		check(clusters.size() == nav.size() - empty.size(), "%s every other region clustered: %d of %d" % [area, clusters.size(), nav.size() - empty.size()])
		# The L10 stair steps under the owner's pose: regions 61-63 (faces 68-70) are among them.
		if area == "L10_DC": check(61 in empty and 62 in empty and 63 in empty, "L10 stair regions 61-63 are polygon-less")
		print("%s: %d regions, %d polygon-less kept out of %d clusters" % [area, nav.size(), empty.size(), clusters.values().reduce(func(a, b): return maxi(a, b), -1) + 1])
	if failures == 0: print("PASS region visibility clusters: polygon-less regions (floor subdivisions) are always drawn")
	quit(0 if failures == 0 else 1)
