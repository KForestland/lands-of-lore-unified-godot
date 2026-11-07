extends SceneTree
const Map = preload("res://scripts/lol2/museum_atlas.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

class Host:
	extends Node3D
	var atlas_explored = null

func run() -> void:
	var quad: Array = [[0, 0], [1, 0], [1, 1], [0, 1]]
	var regions: Array = [
		[quad, 0, 0, [[1, 0, 0]]],
		[quad, 10, 10, [[0, 0, 0], [2, 0, 0]]],
		[quad, 20, 20, [[1, 0, 0]]],
		[quad, 200, 200, []],
		[[], 0, 0, []],
		[quad, 5, 5, [[6, 0, 0]]],
		[quad, 5, 5, [[5, 0, 0]]],
		[quad, 0, 0, []],
	]
	var rows: Array = Map.group_storeys(regions)
	check(int(rows[0].storey) == 2 and int(rows[1].storey) == 2 and int(rows[2].storey) == 2, "a ramp stays one storey")
	check(int(rows[5].storey) == 1 and int(rows[6].storey) == 1, "a linked pair shares a storey")
	check(int(rows[7].storey) == 0 and int(rows[3].storey) == 3 and int(rows[4].storey) == -1, "separate floors and an empty quad")
	check(Map.band(2, 2) == "bright" and Map.band(3, 2) == "faded" and Map.band(0, 2) == "hidden", "current storey, the neighbour, and the rest")
	check(is_equal_approx(Map.fade_color().a, 0.15) and Map.fill_color().is_equal_approx(Color("64765d")), "the fill stays and the fade is 15 percent")
	var atlas: Node = Map.new()
	atlas.storey_offset = 0
	atlas.browse(1)
	atlas.browse(-1)
	check(atlas.storey_offset == 0, "PgUp and PgDn move the storey offset")
	var host := Host.new()
	host.atlas_explored = {"version": 1, "areas": {"L4_HJ": {"full": true, "regions": []}}}
	atlas.walkthrough = host
	atlas.slice_area = "L4_HJ"
	check(atlas.use_filter() and atlas._shown(2, -1), "the atlas reads the host field")
	host.free()
	atlas.free()
	if failures == 0: print("PASS atlas storey draw: bright, faded, hidden")
	quit(1 if failures else 0)
