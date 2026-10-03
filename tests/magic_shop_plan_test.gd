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
	for held in ["12-Tho Broken","94-Iron flute",""]:
		var result: Dictionary = Shop.broken_thohan(held,{"52":0,"49":1})
		assert(result.handled == (held == "12-Tho Broken"))
		assert(result.dialogue == ([423,424,425,426,427,428] if result.handled else []))
		assert(result.set_globals == (["GV_KNOWLEDGE_OF_POWER_ORB"] if result.handled else []))
		rows += 1
	print("PASS: Rashar planner ",rows," branch cases")
	quit()
