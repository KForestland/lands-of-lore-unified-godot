extends RefCounted
## Same-height overlap moves (lead decision 2026-11-13, L14 T3; DEVIATIONS row). tools/prepare_geometry_move.py writes a
## moved map pack (area_moved.json), a moved creature nav (<AREA>.moved.json), a moved region-mover table
## (region_mover/<AREA>.moved.json) and the spec scripts/lol2/geometry_moves/<AREA>.json with every file's sha256.
## The game reads the moved set as one: the map host, progression, portal drawing and the tracker ask here for their paths.
## Meta lol2_geometry_move_off restores the original files. A listed move whose files are missing or do not match the
## spec is refused loudly and the original files are used.
const SPEC := "res://scripts/lol2/geometry_moves/%s.json"

static func spec(area: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.has_meta("lol2_geometry_move_off"): return {}
	var path := SPEC % area
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("area") != area:
		push_error("Geometry move: %s is not a spec for %s" % [path, area]); return {}
	return data

## The pack the area should load: the moved one when its spec is live and the files match, else `original`.
static func pack_path(area: String, original: String) -> String:
	var s := spec(area)
	if s.is_empty(): return original
	var moved := original.get_base_dir() + "/area_moved.json"
	if FileAccess.get_sha256(original) != str(s.inputs.pack) or FileAccess.get_sha256(moved) != str(s.outputs.pack):
		push_error("Geometry move: %s does not match %s (regenerate with tools/prepare_geometry_move.py); original map used" % [moved, SPEC % area])
		return original
	return moved

## Creature nav (region quads and floor ranges) for the same choice.
static func nav_path(area: String, original: String) -> String:
	var s := spec(area)
	if s.is_empty(): return original
	var moved := original.get_basename() + ".moved.json"
	if FileAccess.get_sha256(original) != str(s.inputs.nav) or FileAccess.get_sha256(moved) != str(s.outputs.nav):
		push_error("Geometry move: %s does not match %s; original nav used" % [moved, SPEC % area])
		return original
	return moved

## Region-mover table (tracker): region_mover/<AREA>.moved.json while the move is live.
static func mover_path(area: String, original: String) -> String:
	if spec(area).is_empty(): return original
	var moved := original.get_basename() + ".moved.json"
	if not FileAccess.file_exists(moved):
		push_error("Geometry move: %s is missing; original tracker table used" % moved); return original
	return moved

## Height change of a point in a moved region (0 outside the move): the producer's corner drops of that region,
## interpolated over its triangles 0,1,2 and 0,2,3 (as the floors). Used to carry an old save's position along.
static func delta(area: String, region: int, x: float, z: float, s: Dictionary = {}) -> float:
	if s.is_empty(): s = spec(area)
	if s.is_empty(): return 0.0
	var key := str(region)
	var deltas: Variant = (s.get("corner_deltas", {}) as Dictionary).get(key)
	var q: Variant = (s.get("corner_quads", {}) as Dictionary).get(key)
	if not deltas is Array or not q is Array or (q as Array).size() != 4: return 0.0
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var a := Vector2(q[tri[0]][0], q[tri[0]][1]); var b := Vector2(q[tri[1]][0], q[tri[1]][1]); var c := Vector2(q[tri[2]][0], q[tri[2]][1])
		var det := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(det) < 1e-9: continue
		var u := ((b.y - c.y) * (x - c.x) + (c.x - b.x) * (z - c.y)) / det
		var v := ((c.y - a.y) * (x - c.x) + (a.x - c.x) * (z - c.y)) / det
		var w := 1.0 - u - v
		if u >= -1e-4 and v >= -1e-4 and w >= -1e-4:
			return u * float(deltas[tri[0]]) + v * float(deltas[tri[1]]) + w * float(deltas[tri[2]])
	return float((deltas as Array).min())

## Was a saved point really inside that moved region's ORIGINAL space? (feet between its native floor and ceiling there,
## with a step of slack). A save made standing on top of the region (the owner's 01-16-21: feet 74 on the tunnel's top,
## inside the room's space, while the tracker still named the tunnel) is not carried.
static func inside_original(area: String, region: int, x: float, z: float, feet: float, s: Dictionary = {}) -> bool:
	if s.is_empty(): s = spec(area)
	var key := str(region)
	var q: Variant = (s.get("corner_quads", {}) as Dictionary).get(key)
	var fl: Variant = (s.get("native_floors", {}) as Dictionary).get(key)
	var ce: Variant = (s.get("native_ceilings", {}) as Dictionary).get(key)
	if not q is Array or not fl is Array or not ce is Array: return false
	var f := _interp(q, fl, x, z); var c := _interp(q, ce, x, z)
	return feet >= f - 8.0 and feet <= c

static func _interp(q: Array, corners: Array, x: float, z: float) -> float:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var a := Vector2(q[tri[0]][0], q[tri[0]][1]); var b := Vector2(q[tri[1]][0], q[tri[1]][1]); var c := Vector2(q[tri[2]][0], q[tri[2]][1])
		var det := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(det) < 1e-9: continue
		var u := ((b.y - c.y) * (x - c.x) + (c.x - b.x) * (z - c.y)) / det
		var v := ((c.y - a.y) * (x - c.x) + (a.x - c.x) * (z - c.y)) / det
		var w := 1.0 - u - v
		if u >= -1e-4 and v >= -1e-4 and w >= -1e-4:
			return u * float(corners[tri[0]]) + v * float(corners[tri[1]]) + w * float(corners[tri[2]])
	return float(corners.min())
