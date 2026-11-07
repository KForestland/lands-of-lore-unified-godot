extends SceneTree
## grok R01. Record 1485 is the only new collision quad. The seven crates stack to the mace floor.
## The two height -130 rows are the stack. Region 1171 is not. No item is spawned.
const Wall = preload("res://scripts/lol2/cave_crate_wall.gd")
const Stack = preload("res://scripts/lol2/cave_crate_stack.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Wall.RECORD == 1485, "riser record")
	check(Wall.is_riser({"record": 1485}), "1485 is the riser")
	check(not Wall.is_riser({"record": 1484}), "the band above the lip is not the riser")
	var wall := {"record": 1485, "points_godot": [[474, -130, -12338], [586, -130, -12403], [586, -215, -12403], [474, -215, -12338]]}
	var pts := Wall.corners(wall, Vector3.ZERO)
	var corners_ok: bool = pts.size() == 4 and pts[0] == Vector3(474, -130, -12338) and pts[2] == Vector3(586, -215, -12403)
	check(corners_ok, "riser corners")
	var parent := Node3D.new()
	var body := Wall.add_collider(parent, wall, Vector3.ZERO)
	var body_ok: bool = body.name == "CrateRiser1485" and body.get_child_count() == 1
	check(body_ok, "one collider body")
	parent.free()
	check(Stack.IDS == [94, 95, 96, 97, 112, 121, 122], "the seven crate controls")
	check(Stack.MACE_IDENTITY == 2412466029, "2-Br Mace identity")
	check(Stack.is_stack_mace({"x": 417, "y": 12444, "h": -130, "region": 1092}), "mace in region 1092")
	check(Stack.is_stack_mace({"x": 471, "y": 12480, "h": -130, "region": 1099}), "mace in region 1099")
	check(not Stack.is_stack_mace(Stack.NOT_THIS_STACK), "the bridge-room mace is not this stack")
	check(Stack.reaches_lip([10, 10, 20, 20, 20, 20, 20]), "all seven crates clear the lip")
	check(not Stack.reaches_lip([20, 20, 20]), "three crates stay short of the lip")
	var sizes := {1: Vector3(20, 20, 20), 2: Vector3(20, 20, 20)}
	var centers := {1: Vector3(0, -205, 0), 2: Vector3(40, -205, 0)}
	var stacked: Vector3 = Stack.shove_onto(centers, sizes, 2, Vector3(-30, 0, 0))
	check(stacked == Vector3(0, -185, 0), "a shove onto a crate lifts it: %s" % stacked)
	centers[2] = stacked
	var rested: Dictionary = Stack.rest_all(centers, sizes)
	check(rested[2] == Vector3(0, -185, 0), "the lifted crate stays up")
	check(Stack.riser_gap(Vector3(564, -205, -12367)) > 10.0, "crate 121 starts off the riser")
	if failures == 0: print("PASS cave_crate_stack_test: riser 1485, seven crates, two maces at -130")
	quit(1 if failures else 0)
