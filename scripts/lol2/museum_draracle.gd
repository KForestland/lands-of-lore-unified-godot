extends RefCounted
## Draracle pedestal videos (docs/museum-draracle-videos.md). Region1220 grounded entry: local19 0 plays e032e
## (L3_DHI entry5) and becomes 1, local19 1 plays e033e (entry6) and becomes 2; each then places the player at the
## source op18 return pose. Saved in the Museum checkpoint as "museum_draracle" {"local19"}.
const SOURCE := "res://scripts/lol2/museum_draracle_source.json"
## Checkpoints and saves from before this owner played both clips automatically on arrival.
const LEGACY_LOCAL19 := 2

static func source() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return data if data is Dictionary else {}

static func initial() -> Dictionary: return {"local19":0}

static func validate(state: Variant) -> String:
	if not state is Dictionary or state.size() != 1 or not state.has("local19"): return "Invalid Draracle state."
	var value = state.local19
	if not (value is int or value is float) or not is_finite(float(value)) or value != int(value) or int(value) < 0 or int(value) > 3: return "Invalid Draracle state."
	return ""

static func restore(state: Variant) -> int:
	return int(state.local19) if validate(state).is_empty() else LEGACY_LOCAL19

## Grounded inside region1220 (floor 0, foot tolerance as the region wake owners).
static func inside(src: Dictionary, point: Vector3, foot: float) -> bool:
	if src.is_empty() or foot < float(src.floor) - 1 or foot > float(src.floor) + 3: return false
	var polygon := PackedVector2Array()
	for vertex in src.polygon: polygon.append(Vector2(vertex[0], vertex[1]))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)

## The source step whose predicate admits local19, or {} (local19 2 and 3: no record matches). Local19 3 is set by
## control79's use (museum_draracle_bars.gd).
static func step(src: Dictionary, local19: int) -> Dictionary:
	for row in src.get("steps", []):
		if int(row.local19) == local19: return row
	return {}
