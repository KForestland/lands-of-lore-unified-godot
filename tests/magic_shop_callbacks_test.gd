extends SceneTree
## Every native MAGIC_.WOM handler case must match the planner exactly.
const Shop = preload("res://scripts/lol2/magic_shop.gd")
func _initialize() -> void:
	_run.call_deferred()
static func canon(value: Variant) -> Variant:
	if value is float and value == floorf(value): return int(value)
	if value is Array:
		var out: Array = []
		for item in value: out.append(canon(item))
		return out
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = canon(value[key])
		return out
	return value
func same(expected: Dictionary, actual: Dictionary, label: String) -> bool:
	var e = canon({"handled":expected.handled,"effects":expected.effects})
	var a = canon(actual)
	if str(e) != str(a):
		push_error("%s mismatch\nnative %s\nplanner %s" % [label,str(e),str(a)])
		return false
	return true
func check(condition: bool, label: String) -> bool:
	if not condition: push_error("FAIL: "+label)
	return condition
func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/magic-shop-callbacks-checks.json"))
	var C: Dictionary = data.cases
	var rows := 0
	var ok := true
	for c in C.setup:
		ok = same(c,Shop.setup(c.flags),"setup") and ok; rows += 1
	for c in C.unload:
		ok = same(c,Shop.unload(c.flags,int(c.ambient)),"unload") and ok; rows += 1
	for c in C.pickup:
		ok = same(c,Shop.pickup(int(c.sprite),c.flags),"pickup") and ok; rows += 1
	for c in C.region:
		ok = same(c,Shop.region(int(c.region)),"region") and ok; rows += 1
	for c in C.offer:
		ok = same(c,Shop.offer(c.held,c.flags,int(c.has_broken) != 0,int(c.soul)),"offer") and ok; rows += 1
	for c in C.death:
		ok = same(c,Shop.killed(int(c.message),c.flags,int(c.soul)),"death") and ok; rows += 1
	for c in C.exit:
		ok = same(c,Shop.exit_request(c.flags),"exit") and ok; rows += 1
	for c in C.timer:
		ok = same(c,Shop.timer_expired(c.flags),"timer") and ok; rows += 1
	for c in C.entry:
		ok = same(c,Shop.entry_callback(c.flags),"entry") and ok; rows += 1
	for c in C.completion:
		ok = same(c,Shop.completion(),"completion") and ok; rows += 1
	var quips := 0
	for c in data.quip.cases:
		var plan := Shop.quip_plan(int(c.mask),int(c.bit),c.draws)
		var line := 0 if c.line == null else int(c.line)
		if plan.has("error") or int(plan.mask) != int(c.result) or int(plan.line) != line:
			push_error("quip mismatch %s %s" % [str(c),str(plan)]); ok = false
		quips += 1
	# Router: Rashar wins over the overlapping hotspot0/sprite rects; hotspot slot order.
	var sizes := {0:Vector2i(46,27),1:Vector2i(54,47),2:Vector2i(82,21),3:Vector2i(71,36),4:Vector2i(90,47),5:Vector2i(60,16)}
	ok = check(Shop.route(Vector2i(300,200),{},sizes) == [["npc",0]],"router Shop.route(Vector2i(300,200),{},sizes) == [['npc',0]]") and ok
	ok = check(Shop.route(Vector2i(300,200),{"52":1},sizes) == [],"router Shop.route(Vector2i(300,200),{'52':1},sizes) == []") and ok
	ok = check(Shop.route(Vector2i(200,100),{},sizes) == [["hotspot",0]],"router Shop.route(Vector2i(200,100),{},sizes) == [['hotspot',0]]") and ok
	ok = check(Shop.route(Vector2i(160,340),{},sizes) == [["sprite",4]],"router Shop.route(Vector2i(160,340),{},sizes) == [['sprite',4]]") and ok
	ok = check(Shop.route(Vector2i(160,340),{"46":1,"47":1,"48":1},sizes) == [],"router Shop.route(Vector2i(160,340),{'46':1,'47':1,'48':1},sizes) == []") and ok
	ok = check(Shop.route(Vector2i(100,340),{},sizes) == [["hotspot",2]],"router Shop.route(Vector2i(100,340),{},sizes) == [['hotspot',2]]") and ok
	ok = check(Shop.route(Vector2i(300,355),{},sizes) == [["sprite",0]],"router Shop.route(Vector2i(300,355),{},sizes) == [['sprite',0]]") and ok
	ok = check(Shop.route(Vector2i(420,200),{},sizes) == [["hotspot",4]],"router Shop.route(Vector2i(420,200),{},sizes) == [['hotspot',4]]") and ok
	ok = check(Shop.route(Vector2i(300,400),{},sizes) == [],"router Shop.route(Vector2i(300,400),{},sizes) == []") and ok
	if not ok:
		push_error("FAIL: planner differs from native Rashar handlers")
		quit(1)
		return
	print("PASS: ",rows," native Rashar handler cases, ",quips," native quip cases and host click routing match the planner")
	quit()
