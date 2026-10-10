extends SceneTree
const Completion=preload("res://scripts/lol2/dawn_cast_completion.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_cast_completion_native.json"))
	assert(data.rows.size()==2016)
	var failures=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_cast_failure_native.json"))
	assert(failures.rows.size()==1008)
	data.rows.append_array(failures.rows)
	for row in data.rows:
		var active: Array=[]
		for i in range(int(row.active_before)):active.append([110,15])
		var context={"spell":row.spell,"difficulty":row.difficulty,"mana":row.before,"bar":123,"flags":row.flags_before,"charge":bool(row.charge),"active":active}
		var before: Dictionary=context.duplicate(true)
		var result:=Completion.complete(context)
		assert(not result.has("error"),str(result))
		assert(result.mana==row.remaining and result.bar==row.bar and result.flags==row.flags_after and int(result.sound_requested)==row.sounds and result.active.size()==row.active_after,str(row,result))
		for i in range(active.size()):assert(result.active[i]==active[i])
		if row.duration!=0:assert(result.active[-1]==[int(row.spell),int(row.duration)])
		assert(context==before)
	print("PASS:3024 native dispatch tails, including spell32 allocation and constructor failures; active registration, debit, display and sound-request flag")
	quit()
