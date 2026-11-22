extends SceneTree
const Lips = preload("res://scripts/lol2/l16_terrace_lips.gd")
var failures := 0

func check(ok: bool, m: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", m)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(Lips.HIGH_OF.size() == 10, "ten links")
	check(Lips.HIGH_OF[4959] == 4971, "the stall link is region 4959 onto 4971")
	check(Lips.SLOPE_DEG <= 45.0, "the prism is inside the floor limit")
	check(not Lips.owns({"kind": "floor", "region": 4905}), "the floor-75 ledge is not a lip")
	check(not Lips.owns({"kind": "source_wall", "region": 4959}), "a wall on the link stays a wall")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/maps/L16_CA/area.json"))
	var data: Dictionary = parsed
	var faces: Array = data["faces"]
	var count := 0
	for item in faces:
		var face: Dictionary = item
		if not Lips.owns(face):
			continue
		count += 1
		var ang := Lips.slope_degrees(Lips.slab(face["points"]))
		check(ang <= 45.0 and ang >= 39.0, "region %s prism is %s degrees" % [str(face["region"]), str(ang)])
	check(count == 10, "ten floor quads")
	if failures == 0:
		print("PASS l16_terrace_lip_test: ten link prisms at 40 degrees, drawn quads kept")
	quit(1 if failures else 0)
