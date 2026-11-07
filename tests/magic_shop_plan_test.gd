extends SceneTree
const Shop = preload("res://scripts/lol2/magic_shop.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var rows := 0
	for mask in range(32):
		var flags := {"52":(mask>>0)&1,"55":(mask>>1)&1,"56":(mask>>2)&1,"57":(mask>>3)&1,"58":(mask>>4)&1}
		var result: Dictionary = Shop.entry(flags)
		var expected: Array = []
		if flags["52"] == 0 and flags["55"] != 0 and flags["56"] == 0: expected = [440,441]
		elif flags["52"] == 0 and not (flags["56"] != 0 and flags["57"] == 0) and flags["58"] == 0: expected = [400,401,402,403,404,405,406,407,408,409,410,411,412,413,414,416,417,418,419,420,421,422]
		assert(result.dialogue.size() == expected.size())
		for index in range(expected.size()): assert(int(result.dialogue[index]) == int(expected[index]))
		rows += 1
	# Native 97F: a held broken Thohan with flag49 clear yields the orb knowledge;
	# with flag49 set (orb already given) Rashar returns the fixed Thohan instead.
	for held in ["12-Tho Broken","94-Iron flute",""]:
		for forty_nine in [0,1]:
			var result: Dictionary = Shop.offer(held,{"52":0,"49":forty_nine},false,0)
			var lines: Array = []
			var globals: Array = []
			for effect in result.effects:
				if effect[0] in ["movie","movie_flags"]: lines.append(effect[2])
				if effect[0] == "set_global": globals.append(effect[1])
			if held == "12-Tho Broken":
				assert(lines == ([443,444] if forty_nine else [423,424,425,426,427,428]))
				assert(globals == ([] if forty_nine else ["GV_KNOWLEDGE_OF_POWER_ORB"]))
			else:
				assert(lines == ([429] if held != "" else []) and globals.is_empty())
			rows += 1
	# Dead Rashar ignores every offer (after the host timer stop).
	assert(Shop.offer("12-Tho Broken",{"52":1},true,0).effects == [["stop_timer"]])
	rows += 1
	print("PASS: Rashar planner ",rows," branch cases")
	quit()
