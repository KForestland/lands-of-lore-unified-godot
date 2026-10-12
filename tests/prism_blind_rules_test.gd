extends SceneTree
## prism_blind.gd rules against the source facts (docs/prism-effect-checks.json): thresholds 749/249 of 1..1000,
## equipped/alive gate, refresh without stacking, world-time expiry, region-flag table (Museum all enclosed, Jungle
## open except the listed regions, e.g. Bacatta57 threshold region3501; hosts without a table count as enclosed),
## and the panorama source JSON (7 panels, 430..424 cleared to transparent 871).
const Prism = preload("res://scripts/lol2/prism_blind.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func centre(region: Dictionary) -> Vector3:
	var c := Vector2.ZERO
	for p in region.polygon: c += Vector2(p[0], p[1])
	c /= region.polygon.size()
	return Vector3(c.x, float(region.floor_min), c.y)
func run() -> void:
	var checks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/prism-effect-checks.json"))
	if not check(checks.passed and checks.handler.event == 5 and checks.handler.enclosed_success == "draw > 749" and checks.handler.open_success == "draw > 249", "Source checks"): return
	if not check(not Prism.success(749, true) and Prism.success(750, true) and not Prism.success(249, false) and Prism.success(250, false), "Thresholds"): return
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var blinds := {}
	if not check(Prism.apply(blinds, "a", "", true, rng, false) == 0 and Prism.apply(blinds, "a", Prism.ITEM, false, rng, false) == 0 and blinds.is_empty(), "Ineligible hit drew"): return
	var draws := []
	for i in 400:
		var draw := Prism.apply(blinds, "a", Prism.ITEM, true, rng, true)
		draws.append(draw)
		if not check(draw >= 1 and draw <= Prism.DRAW_MAX and Prism.blinded(blinds, "a") == (draw > 749 or blinds.has("a")), "Draw/blind mismatch"): return
		if Prism.success(draw, true) and not check(is_equal_approx(float(blinds.a), Prism.SECONDS), "No refresh to 10s"): return
		Prism.tick(blinds, 3.0)
	var enclosed_hits: int = draws.filter(func(d): return d > 749).size()
	if not check(enclosed_hits > 60 and enclosed_hits < 140, "Enclosed rate %d/400" % enclosed_hits): return
	blinds = {"b": 2.0}
	Prism.tick(blinds, -1.0); Prism.tick(blinds, NAN)
	if not check(is_equal_approx(float(blinds.b), 2.0), "Invalid delta aged"): return
	Prism.tick(blinds, 2.0)
	if not check(blinds.is_empty(), "Blind did not expire"): return
	var table: Dictionary = Prism.table()
	if not check(table.areas.museum.default_enclosed and table.areas.museum.exceptions.is_empty() and table.areas.hive.default_enclosed and not table.areas.jungle.default_enclosed, "Area defaults"): return
	var r3501: Dictionary = table.areas.jungle.exceptions.filter(func(r): return int(r.region) == 3501)[0]
	if not check(Prism.enclosed_at("jungle", centre(r3501)) and not Prism.enclosed_at("jungle", centre(r3501) + Vector3(0, 0, 4000)), "Jungle region flags"): return
	if not check(Prism.enclosed_at("museum", Vector3(2324, -45, -3413)) and Prism.enclosed_at("", Vector3.ZERO), "Museum/unknown enclosed"): return
	var hive_open: Dictionary = table.areas.hive.exceptions[0]
	if not check(table.areas.hive.exceptions.size() == 3 and not Prism.enclosed_at("hive", centre(hive_open)), "Hive open regions"): return
	var panorama: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/museum_prism_panorama.json"))
	var descriptors: Array = panorama.panels.map(func(p): return int(p.descriptor))
	if not check(descriptors == [430, 429, 428, 427, 426, 425, 424] and panorama.panels.all(func(p): return int(p.cleared_descriptor) == 871 and p.left_normal_inward), "Panorama source"): return
	print("PASS prism_blind_rules: thresholds 749/249 of 1..1000, equipped/alive gate, refresh no stacking, world-time expiry, enclosed rate %d/400, region flags (Museum/Hive enclosed, Jungle 3501 enclosed, open elsewhere, unknown host enclosed), panorama 430..424 -> 871." % enclosed_hits)
	quit()
