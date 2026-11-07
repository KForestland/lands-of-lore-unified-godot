extends RefCounted
## Geometry query only: being over a Rapids floor is not proof of submersion.
var regions: Array = []
## Runtime material changes remove only the affected source regions from this modern water query.
var dry_regions: Dictionary = {}
func _init() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/river_deck/regions.json"))
	for record in source.regions:
		var polygon := PackedVector2Array()
		for p in record.polygon: polygon.append(Vector2(p[0],p[1]))
		regions.append({"id":int(record.region),"polygon":polygon,"floor":float(record.floor)})
func region_at(native: Vector3) -> int:
	for region in regions:
		if dry_regions.get(str(int(region.id)),false):continue
		if Geometry2D.is_point_in_polygon(Vector2(native.x,native.z),region.polygon): return region.id
	return -1
func on_riverbed(native_center: Vector3, grounded: bool, half_height: float = 32.0) -> bool:
	if not grounded: return false
	for region in regions:
		if dry_regions.get(str(int(region.id)),false):continue
		if absf(native_center.y-half_height-region.floor) <= 1.0 and Geometry2D.is_point_in_polygon(Vector2(native_center.x,native_center.z),region.polygon): return true
	return false

const PLANE := -295.0  ## authored liquid plane at the deck base; the native liquid depth is unverified
func submerged(native_center: Vector3) -> bool:
	# Authored liquid plane at deck base -295; exact native liquid depth is unverified.
	# Test the top of the human capsule, excluding the intact deck and banks.
	return native_center.y + 32.0 < PLANE and region_at(native_center) >= 0
## Per-form submersion (owner 2026-10-31: the Lizard drowns in water everywhere): the feet stand 32 under the origin
## (player_form_body.FOOT_OFFSET); the Lizard is under when its feet are below the plane, a Human / Beast when the top of
## its head (feet + 46 / 69) is.
func submerged_form(native_center: Vector3, form: int) -> bool:
	if region_at(native_center) < 0: return false
	var feet := native_center.y - preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	if form == 2: return feet < PLANE
	return feet + preload("res://scripts/lol2/player_form_body.gd").HEIGHTS[clampi(form, 0, 2)] < PLANE
