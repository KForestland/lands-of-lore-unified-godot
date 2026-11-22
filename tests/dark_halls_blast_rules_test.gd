extends SceneTree
const Rules = preload("res://scripts/lol2/dark_halls_blast_rules.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL dark_halls_blast_rules: ", message); quit(1)
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Rules.SOURCE))
	var cases: Array = source.cases
	for row_v in cases:
		var row: Dictionary = row_v
		if Rules.damage_fixed(int(row.distance_fixed), source) != int(row.damage): return fail("original instruction replay mismatch")
	var recipients: Array = source.recipient_cases
	for row_v in recipients:
		var row: Dictionary = row_v
		if Rules.eligible(int(row.flags), int(row.kind)) != bool(row.eligible): return fail("original recipient prefix mismatch")
	if Rules.damage_fixed(200 << 16, source) != 0 or Rules.damage_fixed(-1, source) != 0: return fail("outside radius admitted")
	# Actual source crate448 -> Iron Door84: 84 units apart; the native falloff yields23.
	if Rules.damage(Vector3(-1243, 750, -530), Vector3(-1243, 750, -614), source) != 23: return fail("source448/84 falloff")
	# Topological neighbors are required: a nearby floor island must not receive a blast through empty space.
	var miniature := {"radius": 200, "native_region_cap": 2048, "regions": {
		"0": {"neighbors": [1, 65535, 65535, 65535], "vertices": [[0,0],[65536,0],[65536,65536],[0,65536]]},
		"1": {"neighbors": [0, 65535, 65535, 65535], "vertices": [[0,0],[65536,0],[65536,65536],[0,65536]]},
		"2": {"neighbors": [65535,65535,65535,65535], "vertices": [[0,0],[65536,0],[65536,65536],[0,65536]]}}}
	var regions: Array[int] = Rules.candidate_regions(miniature, 0, Vector2.ZERO)
	if regions != [0, 1]: return fail("disconnected overlapping floor reached")
	if Rules.candidate_regions(miniature, 0, Vector2(1000,1000)) != [0]: return fail("far vertex admitted")
	print("PASS dark_halls_blast_rules:600 original falloff cases,27 recipient-prefix cases, source448/84 damage23, native-radius edge and disconnected-region exclusion")
	quit(0)
