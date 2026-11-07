extends RefCounted
const PREFIX := "hive:Wax_runes:"
static func valid(id: Variant) -> bool:
	if not id is String or not id.begins_with(PREFIX): return false
	var suffix: String = id.trim_prefix(PREFIX)
	return suffix.is_valid_int() and int(suffix) >= 0 and int(suffix) < 23 and suffix == str(int(suffix))
static func next_id(items: Array) -> String:
	for index in range(23):
		var id := PREFIX+str(index)
		if id not in items: return id
	return ""
