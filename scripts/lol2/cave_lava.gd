extends RefCounted
## Source material135 polygons; user-confirmed lethal lava, modern contact policy.
var regions: Array = []
func _init() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/cave_lava/regions.json"))
	for record in source.regions:
		var polygon := PackedVector2Array()
		for vertex in record.polygon: polygon.append(Vector2(vertex[0],vertex[1]))
		regions.append({"id":int(record.region),"floor":float(record.floor),"polygon":polygon})
func contact(native: Vector3, grounded: bool) -> int:
	if not grounded: return -1
	var foot := native.y-32.0
	for region in regions:
		if absf(foot-region.floor)<=1.0 and Geometry2D.is_point_in_polygon(Vector2(native.x,native.z),region.polygon): return region.id
	return -1
