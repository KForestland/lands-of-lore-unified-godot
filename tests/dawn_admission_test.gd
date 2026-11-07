extends SceneTree
const Admission=preload("res://scripts/lol2/dawn_spell_admission.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_admission_native.json"))
	assert(data.rows.size()==240)
	for row in data.rows:
		var context: Dictionary=row.context.duplicate(true)
		context.active=[]
		for i in range(int(context.count)): context.active.append(context.duplicate if i==int(context.get("duplicate_index",0)) and int(context.duplicate)!=0 else 110)
		context.erase("count");context.erase("duplicate")
		var before:=context.duplicate(true)
		var result:=Admission.admit(context)
		assert(not result.has("error"),str(result))
		assert(result.accepted==row.accepted and result.reason==row.reason and result.stored_reason==row.stored_reason and result.b8==row.updated_b8,str(row,result))
		assert(context==before,"Admission must not debit mana or mutate owner state")
	print("PASS:240 native Dawn spell admissions, reason writes and indirect-target flags; no mana debit")
	quit()
