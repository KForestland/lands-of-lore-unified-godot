extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL leftovers: ",message)
func read(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))
func _initialize() -> void:
	var hive := read("res://assets/lol2/generated/hive_review/hive.json")
	for region in [121,122,1004,846,862,845]:
		var floors: Array = hive.faces.filter(func(f):return f.kind=="floor" and int(f.get("region",-1))==region)
		check(not floors.is_empty(),"Hive reported bridge/platform floor %d"%region)
		for floor_face in floors:
			check(not str(floor_face.material) in hive.alpha_cutout_materials,"floor is not alpha cutout")
			var points := PackedVector2Array()
			for p in floor_face.points: points.append(Vector2(p[0],p[2]))
			check(not Geometry2D.triangulate_polygon(points).is_empty(),"floor has a valid polygon")
	var image := Image.load_from_file("res://assets/lol2/generated/hive_review/material_21.png")
	check(not image.is_empty() and not image.detect_alpha(),"bridge lava-rock texture is opaque")
	var represented: Dictionary = {}
	for binding in hive.wall_bindings: represented[int(binding.wall_record)]=true
	for face in hive.faces:
		if face.has("wall_record"): represented[int(face.wall_record)]=true
	for record in [1609,1610]: check(represented.has(record),"Hive brazier source wall %d"%record)
	var blockers := read("res://assets/lol2/generated/region_blockers/L5_HC.json")
	for region in [1067,387,388,389,390]: check(region in blockers.blocked_regions.map(func(r):return int(r)),"boulder gap blocker %d"%region)
	var cave := read("res://assets/lol2/generated/wall_review/walls.json")
	for record in [1484,1485,1486,1487]:
		check(cave.walls.any(func(w):return int(w.record)==record),"Cave underbridge source wall %d"%record)
	var props := read("res://assets/lol2/generated/jungle_props/props.json")
	var found := false
	for group in props.groups:
		for row in group.instances:
			if int(row[3])==5211:
				found=true
				check(group.material=="prop_727","reported Jungle tree uses original bare-trunk art")
	check(found,"reported tree placement retained")
	if failures==0: print("PASS map leftovers source floors/opaque bridge/brazier walls/boulder blockers/Cave opening/trunk art; no original collision or matched-view claim")
	quit(0 if failures==0 else 1)
