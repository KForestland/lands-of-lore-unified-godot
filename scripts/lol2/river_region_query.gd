extends RefCounted
## Geometry query only: being over a Rapids floor is not proof of submersion.
var regions: Array = []
func _init() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/river_deck/regions.json"))
	for record in source.regions:
		var polygon := PackedVector2Array()
		for p in record.polygon: polygon.append(Vector2(p[0],p[1]))
		regions.append({"id":int(record.region),"polygon":polygon,"floor":float(record.floor)})
func region_at(native: Vector3) -> int:
	for region in regions:
		if Geometry2D.is_point_in_polygon(Vector2(native.x,native.z),region.polygon): return region.id
	return -1
func on_riverbed(native_center: Vector3, grounded: bool, half_height: float = 32.0) -> bool:
	if not grounded: return false
	for region in regions:
		if absf(native_center.y-half_height-region.floor) <= 1.0 and Geometry2D.is_point_in_polygon(Vector2(native_center.x,native_center.z),region.polygon): return true
	return false

func submerged(native_center: Vector3) -> bool:
	# Authored liquid plane at deck base -295; exact native liquid depth is unverified.
	# Test the top of the human capsule, excluding the intact deck and banks.
	return native_center.y + 32.0 < -295.0 and region_at(native_center) >= 0
