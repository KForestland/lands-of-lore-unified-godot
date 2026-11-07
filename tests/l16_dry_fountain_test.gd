extends SceneTree
## grok R04. Prop 210 breaks into water and nine pad clumps. The greenhouse planters stay out.
const Fountain = preload("res://scripts/lol2/l16_dry_fountain.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Fountain.BALL_RECORD == 210, "the orb is prop 210")
	var nine: bool = Fountain.CLUMPS == 9 and Fountain.LICHEN_AT.size() == 9
	check(nine, "nine clumps")
	check(Fountain.validate(Fountain.initial()).is_empty(), "initial state")
	var broken: Dictionary = Fountain.apply_break(Fountain.initial())
	var water_on: bool = broken.broken and broken.water and broken.taken.is_empty()
	check(water_on, "break turns the water on")
	check(Fountain.apply_break(broken) == broken, "a second break changes nothing")
	var one: Dictionary = Fountain.apply_take(broken, 0)
	check(one.taken == [0], "the first clump is taken")
	check(Fountain.apply_take(one, 0) == one, "the same clump is not taken twice")
	check(Fountain.apply_take(Fountain.initial(), 0) == Fountain.initial(), "no lichen before the break")
	check(Fountain.clump_id(3) == "act2:L16_CA:pad_lichen3", "pad clump id")
	check(Items.definition(Fountain.clump_id(0)) == 122, "pad clump is black lichen")
	check(str(Items.row(Fountain.clump_id(0)).get("grade", "")).contains("prop 210"), "grade names prop 210")
	check(Items.definition("act2:L16_CA:lichen518") == 122, "a greenhouse planter id still resolves")
	check(not Fountain.clump_id(0).begins_with("act2:L16_CA:lichen"), "pad ids stay off the planter prefix")
	check(Fountain.validate(broken).is_empty(), "broken state is valid")
	var wet: Dictionary = broken.duplicate(true)
	wet.broken = false
	wet.water = true
	wet.taken = []
	check(not Fountain.validate(wet).is_empty(), "water without the break is refused")
	var dry: Dictionary = broken.duplicate(true)
	dry.water = false
	check(not Fountain.validate(dry).is_empty(), "a break without water is refused")
	if failures == 0: print("PASS l16_dry_fountain_test: prop 210, water, nine pad clumps")
	quit(1 if failures else 0)
