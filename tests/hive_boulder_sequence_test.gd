extends SceneTree
const Plan=preload("res://scripts/lol2/hive_boulder_sequence.gd")
func _initialize() -> void:
	var value:=Plan.initial()
	assert(Plan.advance(value,100).groups.is_empty() and value==Plan.initial())
	assert(Plan.begin(value)==[6778] and Plan.begin(value).is_empty())
	Plan.advance(value,0.5)
	assert(value.phase==1 and Plan.offsets(value).ceiling794==-62.5)
	var saved:=Plan.canonical(JSON.parse_string(JSON.stringify(value)))
	assert(saved==value)
	var crossed:=Plan.advance(value,Plan.CLOSE_SECONDS-0.5)
	assert(crossed.groups==[6250] and value.phase==2)
	Plan.advance(value,1)
	assert(Plan.offsets(value).floor1217==-25 and Plan.offsets(value).floor1218==-25)
	var events:=Plan.advance(value,100)
	assert(events.groups==[6806] and value.phase==3)
	assert(Plan.offsets(value)=={"ceiling794":-128.0,"floor1216":-313.0,"floor1217":-313.0,"floor1218":-313.0,"ceiling801":100.0})
	assert(Plan.advance(value,100).groups.is_empty() and Plan.validate(value).is_empty())
	var coarse:=Plan.initial()
	Plan.begin(coarse)
	assert(Plan.advance(coarse,100).groups==[6250,6806] and coarse==value)
	# Save at every phase, then compare uninterrupted and JSON-restored execution.
	for checkpoint in [0.0,0.5,Plan.CLOSE_SECONDS,5.0,14.0,20.0]:
		var original:=Plan.initial()
		Plan.begin(original)
		Plan.advance(original,checkpoint)
		var restored: Dictionary=Plan.restore(JSON.parse_string(JSON.stringify(original))).state
		assert(Plan.advance(original,20)==Plan.advance(restored,20))
		assert(original==restored)
	var fine:=Plan.initial()
	Plan.begin(fine)
	var fine_events: Array=[]
	for step in range(2000): fine_events.append_array(Plan.advance(fine,0.01).groups)
	assert(fine_events==[6250,6806] and fine==coarse)
	for delta in [-1.0,INF,NAN]:
		var valid:=Plan.initial()
		Plan.begin(valid)
		var before:=valid.duplicate(true)
		assert(Plan.advance(valid,delta).has("error") and valid==before)
	for invalid in [null,[],{}, {"version":true,"phase":0,"elapsed":0}, {"version":1,"phase":-1,"elapsed":0}, {"version":1,"phase":0.5,"elapsed":0}, {"version":1,"phase":0,"elapsed":true}]:
		assert(Plan.restore(invalid).has("error"))
	for bad in [{"version":1,"phase":0,"elapsed":0.1},{"version":1,"phase":1,"elapsed":Plan.CLOSE_SECONDS},{"version":1,"phase":2,"elapsed":Plan.LOWER_SECONDS},{"version":1,"phase":3,"elapsed":INF}]:
		var before: Dictionary=bad.duplicate(true)
		assert(not Plan.validate(bad).is_empty() and Plan.advance(bad,1).has("error") and bad==before)
	print("PASS saved boulder surface sequence, callback order, coarse stepping, slope-preserving offsets, relative exit and malformed-state rejection; host speeds are adapters")
	quit()
