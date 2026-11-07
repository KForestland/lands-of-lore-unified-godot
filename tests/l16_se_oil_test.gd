extends SceneTree
const Oil = preload("res://scripts/lol2/l16_se_oil.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Oil.FOUNTAIN_RECORD == 392, "oil is prop 392")
	check(Oil.DOORS == [80, 81, 98], "named fire doors stay listed")
	check(Oil.validate(Oil.initial()).is_empty(), "initial state")
	var row: Dictionary = Items.row(Oil.BOW)
	check(int(row.get("definition", -1)) == 35, "Dark Bow definition 35")
	check(str(row.get("name", "")) == "36-Darkbow", "name slot 36-Darkbow")
	check(str(row.get("label", "")) == "Dark Bow", "label Dark Bow")
	check(int(row.get("identity", 0)) == 3582735614, "row 24 identity")
	check(int(row.get("handler", -1)) == 0, "drain handler stays off")
	var blue: Dictionary = Items.row(Oil.BLUE)
	check(str(blue.get("label", "")) == "Blue Bow" and Oil.BLUE != Oil.BOW, "blue bow id stays")
	check(Items.definition("act2:L16_CA:pad_lichen0") == 122, "pad lichen prefix stays")
	if failures == 0: print("PASS l16_se_oil_test: prop 392, dormant row 24, blue bow stays")
	quit(1 if failures else 0)
