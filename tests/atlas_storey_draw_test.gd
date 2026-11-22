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
	var beside: Array = [[5, 5], [6, 5], [6, 6], [5, 6]]
	var regions: Array = [
		[quad, 0, 0, [[1, 0, 0]]],
		[quad, 10, 10, [[0, 0, 0], [2, 0, 0]]],
		[quad, 20, 20, [[1, 0, 0]]],
		[quad, 200, 200, []],
		[[], 0, 0, []],
		[quad, 5, 5, [[6, 0, 0]]],
		[quad, 5, 5, [[5, 0, 0]]],
		[quad, 0, 0, []],
		[beside, 300, 300, []],
	]
	var rows: Array = Map.group_storeys(regions)
	check(int(rows[0].storey) == 0 and int(rows[1].storey) == 0 and int(rows[2].storey) == 0, "a ramp stays one storey")
	check(int(rows[5].storey) == 0 and int(rows[6].storey) == 0 and int(rows[7].storey) == 0, "unlinked rooms at the same height are the same storey (BJ05: fragments are not storeys)")
	check(int(rows[3].storey) == 1 and int(rows[4].storey) == -1, "a room over the others is the next storey; an empty quad has none")
	check(int(rows[8].storey) == 1, "a high room beside the others, over nothing, joins the storey nearest its height")
	check(Map.band(2, 2) == "bright" and Map.band(3, 2) == "faded" and Map.band(0, 2) == "hidden", "current storey, the neighbour, and the rest")
	var hall: Array = [[0, 0], [200, 0], [200, 200], [0, 200]]
	var stair: Array = [[200, 0], [240, 0], [240, 40], [200, 40]]
	var above: Array = [[50, 50], [80, 50], [80, 80], [50, 80]]
	var piled: Array = [
		[hall, 0, 0, [[1, 220, 20]]],
		[stair, 0, 0, [[0, 220, 20], [2, 220, 20]]],
		[stair, 30, 30, [[1, 220, 20], [3, 65, 65]]],
		[above, 60, 60, [[2, 220, 20]]],
	]
	var pile_rows: Array = Map.group_storeys(piled)
	check(int(pile_rows[0].storey) == int(pile_rows[1].storey) and int(pile_rows[1].storey) == int(pile_rows[2].storey), "the side stair stays with the hall")
	check(int(pile_rows[3].storey) != int(pile_rows[0].storey), "a room stacked on the hall is another storey")
	var nav: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/creature_nav/L10_DC.json"))
	var real: Array = Map.group_storeys(nav.regions)
	check(int(real[4148].storey) >= 0 and int(real[4148].storey) != int(real[2435].storey), "catacomb hall 4148 is not the surface quad 2435")
	var depths: Array = Map.section_depths(nav.regions)
	var home := int(real[4148].storey)
	var page := int(depths[4148])
	var low := 0
	var high := 0
	for i in nav.regions.size():
		if int(real[i].storey) != home or int(depths[i]) != page: continue
		var floor_y := float(nav.regions[i][1])
		if floor_y < -40.0: low += 1
		elif floor_y > -20.0: high += 1
	check(low > 100 and high == 0, "the stand's page is the catacombs (%d low, %d high)" % [low, high])
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
