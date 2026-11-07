extends SceneTree
const Review = preload("res://scripts/lol2/jungle_review.gd")
const Hall = preload("res://scripts/lol2/l14_hall_clear.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var review: Node = Review.new()
	review.geometry_file = "res://assets/lol2/generated/maps/L14_HT/area.json"
	for index in [1810, 9634, 9656, 9657, 9670]:
		check(is_equal_approx(review._lip_top(index), 110.0), "L14 face %d clips at 110" % index)
	check(review._lip_top(8225) < 0.0, "the region 15 wall stays")
	review.geometry_file = Review.ROOT + "jungle.json"
	check(is_equal_approx(review._lip_top(10239), 104.0) and is_equal_approx(review._lip_top(9929), 64.0), "jungle lips stay")
	review.free()
	var map := Node3D.new()
	root.add_child(map)
	var hall: Node = Hall.attach(map)
	check(hall.name == "L14HallClear" and hall.get_child_count() == 1 and hall.get_child(0) is MeshInstance3D, "black quad")
	check(not hall.get_child(0) is CollisionObject3D, "the clear has no collision")
	var mesh := hall.get_child(0) as MeshInstance3D
	var mat := mesh.material_override as StandardMaterial3D
	check(mat.albedo_color.is_equal_approx(Color(0, 0, 0, 1)) and mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "unshaded black, both sides")
	hall.queue_free()
	map.queue_free()
	await process_frame
	if failures == 0: print("PASS l14 hall clear: black opening and ceiling clip")
	quit(1 if failures else 0)
