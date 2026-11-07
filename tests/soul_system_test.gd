extends SceneTree
## SOUL-SYSTEM: one good/evil value (GV_LUTHERS_SOUL, global 0) with the original start value 5 and the 0..10 cap that the
## Jungle opcode-206 path applies; level-script soul changes add through shared_global_defaults.add_soul. Room scripts that
## the native Rashar/room comparisons pin (magic_shop.gd) keep their native arithmetic.
const G := preload("res://scripts/lol2/shared_global_defaults.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void:
	var bank := {}
	check(G.soul(bank) == 5, "a new game starts at 5")
	check(G.add_soul(bank, 2) == 7 and int(bank.GV_LUTHERS_SOUL) == 7, "+2 is stored")
	check(G.add_soul(bank, 9) == 10, "the value stops at 10")
	check(G.add_soul(bank, -15) == 0, "the value stops at 0")
	check(G.soul_after({"GV_LUTHERS_SOUL": 10}, 1) == 10 and G.soul_after({}, -1) == 4, "soul_after previews without writing")
	check(G.soul({"GV_LUTHERS_SOUL": 0}) == 0, "an explicit saved 0 is kept, not the default")
	# No script may write the soul by raw arithmetic any more (each write goes through the helper or a clamp).
	var dir := DirAccess.open("res://scripts/lol2")
	for f in dir.get_files():
		if not f.ends_with(".gd"): continue
		var text := FileAccess.get_file_as_string("res://scripts/lol2/" + f)
		for line in text.split("\n"):
			if line.strip_edges().begins_with("#"): continue
			var raw := RegEx.create_from_string("GV_LUTHERS_SOUL\\s*=\\s*int\\(.*\\)\\s*[-+]").search(line)
			check(raw == null, "%s writes the soul without the cap: %s" % [f, line.strip_edges()])
	print("Soul system: %d failures" % failures)
	if failures == 0: print("PASS soul_system")
	quit(1 if failures else 0)
