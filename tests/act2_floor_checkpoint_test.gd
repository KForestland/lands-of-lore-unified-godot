extends SceneTree
func _initialize()->void:
	var codec=load("res://scripts/lol2/act2_floor_checkpoint.gd")
	var good={"version":1,"clock":0.25,"motions":{"40":{"height":-39,"remaining":19,"fraction":32768,"speed":2}}}
	assert(codec.error(good).is_empty())
	for key in ["height","remaining","fraction","speed"]:
		var bad=good.duplicate(true);bad.motions["40"][key]=0.5
		assert(not codec.error(bad).is_empty())
	for bad in [{},[],{"version":1,"clock":-1.0,"motions":{}},{"version":1,"clock":INF,"motions":{}},{"version":1,"clock":0,"motions":{"-1":good.motions["40"]}}]:assert(not codec.error(bad).is_empty())
	var overflow=good.duplicate(true);overflow.motions["40"].remaining=65535
	assert(not codec.error(overflow).is_empty())
	print("PASS L19 floor packet validator: valid pending data; fractional, malformed, negative-clock, infinite-clock and overflow fields rejected")
	quit()
