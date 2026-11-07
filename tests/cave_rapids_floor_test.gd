extends SceneTree
const State=preload("res://scripts/lol2/cave_rapids_floor_state.gd")
func _initialize() -> void:
	var s:=State.initial();assert(State.validate(s).is_empty())
	var unchanged:=s.duplicate(true);assert(State.advance_accepted(s,65536).is_empty() and s==unchanged)
	assert(State.start(s));assert(State.validate(s).is_empty())
	for f in s.floors.values():assert(f.material==0 and f.derived_byte39==0 and f.height==-395)
	var receipts: Array=[];var local7:=0
	for tick in range(1,23):
		# Every intermediate JSON save must resume with exactly the same next result.
		var restored:=State.canonical(JSON.parse_string(JSON.stringify(s)))
		assert(State.validate(restored).is_empty())
		var events:=State.advance_accepted(s,65536)
		assert(State.advance_accepted(restored,65536)==events and s==restored)
		for event in events:
			receipts.append([tick,event.region,event.event])
			if State.local7_write(event):local7=1
		assert(local7==(1 if tick>=21 else 0))
		assert(State.validate(s).is_empty())
	# Native speed100 -> integer250; quota273066/tick, whole-unit floor heights.
	assert(receipts==[[7,7,4],[16,11,4],[21,10,4]])
	assert(s.floors["7"].height==-367 and s.floors["11"].height==-332 and s.floors["10"].height==-311)
	assert(State.advance_accepted(s,65536).is_empty())
	assert(not State.local7_write({"region":10,"event":6}))
	assert(not State.local7_write({"region":7,"event":4}))
	var partial:=State.initial();assert(State.start(partial));State.advance_accepted(partial,65536)
	assert(partial.floors["10"].height==-391 and partial.floors["10"].fraction==10922)
	assert(State.start(partial) and partial.floors["10"].height==-391 and partial.floors["10"].fraction==0)
	for key in ["material","derived_byte39","remaining","speed","fraction"]:
		var bad:=partial.duplicate(true);bad.floors["10"][key]=99999;var before:=bad.duplicate(true)
		assert(not State.validate(bad).is_empty());assert(not State.start(bad))
		assert(State.advance_accepted(bad,65536).is_empty() and bad==before)
	var before:=partial.duplicate(true);assert(State.advance_accepted(partial,-1).is_empty() and partial==before)
	print("PASS three native rapids material/motion contracts, 22 JSON continuation points, exact completion ticks/local7 dispatch, retrigger fractions and invalid-state atomicity; world host remains separate.")
	quit()
