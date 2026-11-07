extends SceneTree
const Active=preload("res://scripts/lol2/dawn_active_spells.gd")
func equivalent(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for k in a:
			if not b.has(k) or not equivalent(a[k],b[k]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]):return false
		return true
	return a==b
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_active_expiry_native.json"))
	assert(data.rows.size()==682)
	for row in data.rows:
		var before: Array=row.active.duplicate(true)
		assert(equivalent(Active.expire(row.active,row.exclusive,row.tick),row.expected),str(row))
		assert(row.active==before)
	print("PASS:682 native active-list expiry cases including exact byte compaction and cursor behavior")
	quit()
