extends SceneTree
const Launch=preload("res://scripts/lol2/dawn_projectile_launch.gd")
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_projectile_launch_native.json"))
	for row in fixture.rows:
		var actual:=Launch.plan(row.context)
		if JSON.parse_string(JSON.stringify(actual))!=row.expected:
			push_error("Launch differs: %s expected %s actual %s"%[row.context,row.expected,actual]);quit(1);return
	var bad: Dictionary=fixture.rows[0].context.duplicate(true)
	bad.placements=[true,1]
	if not Launch.plan(bad).has("error"):push_error("Accepted nonboolean placement");quit(1);return
	print("PASS: %d original projectile launch comparisons, projected placement, origin fallback, rejection, signed wrap and collision flags. World queries supplied; atan bearing unbound."%fixture.rows.size())
	quit()
