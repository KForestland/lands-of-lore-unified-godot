extends SceneTree
## Owner 2026-10-24 (r12b F10 at -711.8,-4146.2): an outer Jungle edge without a wall record (region589 edge0) showed
## the mountain backdrop at eye level. Untextured outer boundary walls now borrow the nearest textured outer wall's
## texture; textured walls, interior spans and the collision are unchanged.
## Owner r12h 2026-10-25 ("textures transparent, can see the sky box"): outer walls with the fully clear cut-out material
## 469 (the roots forest, F10 2026-10-24 17:58 at -3486,569), interior step spans without a wall record, and the 49
## floorless (impassable) floors are filled as well. No fill borrows a fully clear material; upper spans stay undrawn.
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_edge_fill: ", message); quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	if not scene.fill_untextured_edges: return fail("Edge fill is off in the Jungle")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var span_start: int = int(data.interior_audit.get("span_start", data.faces.size() - int(data.interior_audit.span_count)))
	var fills: Dictionary = scene._edge_fills(data, span_start)
	var untextured := 0
	for index in span_start:
		if data.faces[index].kind == "wall" and not data.faces[index].has("material"): untextured += 1
	var reported := -1
	for index in span_start:
		var face: Dictionary = data.faces[index]
		if int(face.region) == 589 and face.kind == "wall" and not face.has("material") and is_equal_approx(float(face.points[0][0]), -783.0): reported = index
	if reported < 0: return fail("Region589 untextured outer wall not found")
	if not fills.has(reported) or not data.materials.has(fills[reported].material): return fail("Reported wall not filled")
	var clear: Dictionary = scene._clear_materials(data)
	if not clear.has("469") or clear.size() != 1: return fail("Expected exactly material 469 to be fully clear, got %s" % [clear.keys()])
	var counts := {"outer": 0, "clear": 0, "step": 0, "floor": 0}
	for index in fills:
		var face: Dictionary = data.faces[index]
		if clear.has(str(fills[index].material)): return fail("Fill %d borrows the clear material" % index)
		if fills[index].points != face.points or fills[index].uv.size() != face.points.size(): return fail("Fill changed the geometry of %d" % index)
		if face.kind == "floor":
			if face.has("material"): return fail("Filled a textured floor %d" % index)
			counts.floor += 1
		elif index >= span_start:
			if face.has("material"): return fail("Filled a textured interior span %d" % index)
			counts.step += 1
		elif face.has("material"):
			if not clear.has(str(face.material)): return fail("Filled a textured outer wall %d" % index)
			counts.clear += 1
		else:
			counts.outer += 1
	if counts.floor != 49: return fail("Expected the 49 floorless floors filled, got %d" % counts.floor)
	if counts.clear == 0 or counts.step == 0: return fail("Clear outer walls or step spans not filled: %s" % counts)
	var roots := -1
	for index in span_start:
		var face: Dictionary = data.faces[index]
		if int(face.region) == 3556 and face.kind == "wall" and str(face.get("material", "")) == "469": roots = index
	if roots < 0 or not fills.has(roots): return fail("Roots-forest clear wall (region3556) not filled")
	print("PASS jungle_edge_fill: %s fills (%d untextured outer walls, rest degenerate); region589 edge0 -> material %s; region3556 -> %s" % [counts, untextured, fills[reported].material, fills[roots].material])
	quit(0)
