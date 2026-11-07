extends SceneTree
const Entry=preload("res://scripts/lol2/dawn_cast_entry.gd")
func _initialize() -> void:
	var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_cast_entry_native.json"))
	assert(fixture.rows.size()==700)
	for row in fixture.rows:
		var before: Dictionary=row.context.duplicate(true)
		var result:=Entry.begin(row.context,row.event,row.enabled)
		assert(not result.has("error"),str(result))
		for field in ["checked","admitted","entry_flags","stored_reason"]: assert(result[field]==row.expected[field],str(field,row,result))
		assert(Entry.finish_event(result.entry_flags,row.event).flags==row.expected.return_flags)
		assert(result.supported_effect==(result.admitted and int(row.context.spell)!=0))
		assert(row.context==before)
	assert(Entry.finish_event(-1,true).has("error"))
	print("PASS:700 native cast-entry boundaries; silent re-admission, indirect flag reset, unconditional post-event rotation, zero spell excluded from effects")
	quit()
