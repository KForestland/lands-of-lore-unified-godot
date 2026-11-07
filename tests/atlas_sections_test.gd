extends SceneTree
const Map = preload("res://scripts/lol2/museum_atlas.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

class Walk:
	extends Node3D
	var player: Node3D
	var atlas_explored = null

func _square(x0: float, z0: float, x1: float, z1: float) -> Array:
	return [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]

func run() -> void:
	var regions: Array = [
		[_square(0, 0, 100, 100), 0, 0, [[1, 50, 50]]],
		[_square(40, 40, 60, 60), 10, 10, [[0, 50, 50], [2, 50, 50]]],
		[_square(45, 45, 55, 55), 20, 20, [[1, 50, 50]]],
		[_square(200, 200, 220, 220), 0, 0, []],
		[_square(45, 45, 55, 55), 200, 200, []],
		[_square(-100, -100, 0, 0), 0, 0, [[6, -50, -50]]],
		[_square(-60, -60, -40, -40), 0, 0, [[5, -50, -50]]],
		[_square(0, 0, 20, 20), 400, 400, [[8, 10, 10]]],
		[_square(0, 0, 20, 20), 400, 400, [[7, 10, 10]]],
	]
	var depths: Array = Map.section_depths(regions)
	var expect: Array = [0, 1, 2, 0, 0, 0, 1, 0, 0]
	var same := depths.size() == expect.size()
	if same:
		for i in expect.size():
			if int(depths[i]) != int(expect[i]):
				same = false
	check(same, "containment depth %s" % [depths])
	check(Map.section_name(0) == "Floor" and Map.section_name(1) == "Inside 1" and Map.section_name(7) == "Inside 7", "Floor and Inside N")
	var atlas: Node = load("res://scripts/lol2/museum_atlas.gd").new()
	atlas.section_hi = 2
	atlas.browse_section(1)
	check(int(atlas.section_offset) == 1, "one Section step")
	atlas.browse_section(1)
	atlas.browse_section(1)
	check(int(atlas.section_offset) == 0, "Section wraps")
	var walk := Walk.new()
	var body := Node3D.new()
	body.position = Vector3(5, 0, 5)
	walk.player = body
	walk.add_child(body)
	root.add_child(walk)
	atlas.walkthrough = walk
	var polygon := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	atlas.slices = [{"polygon": polygon, "region": 0, "storey": 0, "floor": 0.0, "section": 2}]
	atlas.section_of = {0: 2}
	atlas.section_hi = 2
	atlas.section_offset = 0
	check(int(atlas._depth_at(0)) == 2, "player depth")
	atlas.browse_section(1)
	check(int(atlas.section_offset) == -2 and int(atlas._depth_at(0)) == 0, "Section wraps to Floor")
	walk.atlas_explored = {"version": 1, "areas": {"L14_HT": {"full": false, "regions": [4]}}}
	atlas.slice_area = "L14_HT"
	check(atlas.use_filter() and atlas._shown(4, -1) and not atlas._shown(5, -1), "the atlas reads the host field")
	atlas.free()
	walk.free()
	if failures == 0:
		print("PASS atlas sections: Floor and Inside N")
	quit(1 if failures else 0)
