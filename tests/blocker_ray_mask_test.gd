extends SceneTree
## Lesson of r12r (lead, 2026-10-30): the region blockers moved to their own physics layer (1<<9) and three Museum line-of-sight rays
## that kept the default mask (hourglass strike, gallery aim, wheel door) hit them, failing the detour campaign — a chain leg the
## affected suite does not register. This headless check scans every scripts/lol2 script for a
## PhysicsRayQueryParameters3D.create(from, to) call with two arguments (default mask = everything) that is not followed by a
## collision_mask assignment within six lines. Every aim, reach or line-of-sight ray must pass a mask (1 for walls only, or
## region_blockers.RAY_MASK = everything but the blockers) or set one, or be listed in ALLOWED with the reason it should see blockers.
const ROOT := "res://scripts/lol2/"
const ALLOWED := {}  # "path:line": "reason it must see the blockers"
var failures := 0

func scripts(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if d.current_is_dir():
			if not name.begins_with("."): scripts(dir + name + "/", out)
		elif name.ends_with(".gd"): out.append(dir + name)
		name = d.get_next()

## Argument count of the create(...) call starting at `open` (index of the '('), by balanced brackets.
func argument_count(src: String, open: int) -> int:
	var depth := 0; var args := 1; var seen := false
	for i in range(open, src.length()):
		var c := src[i]
		if c == "(" or c == "[" or c == "{": depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
			if depth == 0: return args if seen else 0
		elif c == "," and depth == 1: args += 1
		elif c != " " and c != "\t" and c != "\n": seen = true
	return args

func run() -> void:
	var files: Array = []
	scripts(ROOT, files)
	files.sort()
	var checked := 0
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		var key := "PhysicsRayQueryParameters3D.create("
		var at := src.find(key)
		while at >= 0:
			checked += 1
			var open := at + key.length() - 1
			var line := src.count("\n", 0, at) + 1
			if argument_count(src, open) <= 2:
				var lines := src.split("\n")
				var following := ""
				for i in range(line, mini(line + 6, lines.size())): following += lines[i] + "\n"
				var masked := following.contains(".collision_mask =") or following.contains(".collision_mask=")
				var id := "%s:%d" % [path.trim_prefix("res://"), line]
				if not masked and not ALLOWED.has(id):
					failures += 1
					print("FAIL: default-mask ray query (sees the region blockers): " + id)
			at = src.find(key, open)
	print("Blocker ray mask: %d create() calls in %d scripts, %d failures" % [checked, files.size(), failures])
	if failures == 0: print("PASS blocker ray mask: every PhysicsRayQueryParameters3D.create in scripts/lol2 passes or sets a collision mask")
	quit(0 if failures == 0 else 1)

func _initialize() -> void: run.call_deferred()
