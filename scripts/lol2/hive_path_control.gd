extends RefCounted
## Native behavior7 path-index controls; movement and callback effects stay external.
const Numbers = preload("res://scripts/lol2/save_value_rules.gd")
static func _valid(route: Variant, index: Variant) -> bool:
	return route is Dictionary and Numbers.integer(route.get("first"),65535) and Numbers.integer(route.get("count"),127) and int(route.count)>=2 and Numbers.integer(route.get("flags"),255) and (index is int or index is float) and is_finite(float(index)) and index==floor(float(index)) and abs(index)<route.count

static func select_marker(route: Variant, index: Variant) -> Dictionary:
	if not _valid(route,index): return {"error":"Invalid source path or signed index."}
	return {"marker":int(route.first)+absi(int(index))}

static func advance_index(route: Variant, index: Variant, b8: Variant) -> Dictionary:
	if not _valid(route,index) or not Numbers.integer(b8,255): return {"error":"Invalid source path advancement."}
	var next := int(index)+1
	if next>=int(route.count): next=0 if int(route.flags)&1 else -(int(route.count)-2)
	# Event22 still needs native virtualB8 owner resolution and event dispatch.
	return {"index":next,"event22_requested":int(index)>next,"b8":int(b8)&0xcf}
