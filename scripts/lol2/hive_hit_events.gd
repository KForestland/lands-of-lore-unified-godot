extends RefCounted
## B4298 orchestration. Event helpers stage their external effects until commit.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func _call(helpers: Dictionary, name: String, args: Array) -> Dictionary:
	if not helpers.get(name) is Callable or not helpers[name].is_valid(): return {"error":"Missing hit event helper: "+name}
	var value: Variant = helpers[name].callv(args)
	if value is Dictionary and value.has("error"): return value
	return {"value":value}
static func _sum(left: int, right: Variant) -> Dictionary:
	if not right is int and not right is float: return {"error":"Invalid event result."}
	if not is_finite(right) or right!=floor(right) or right< -2147483648 or right>4294967295: return {"error":"Invalid event result."}
	return {"value":(left+int(right))&0xffffffff}
static func run(saved: Variant, supplied_request: Variant, helpers: Dictionary) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("flags15"),255) or not supplied_request is Dictionary: return {"error":"Invalid hit event context."}
	var actor: Dictionary = saved.duplicate(true);var request: Dictionary = supplied_request.duplicate(true)
	var total := 0
	if (int(actor.flags15)&4)==0: return {"state":actor,"request":request,"result":0}
	for pass_index in range(2):
		var listing := _call(helpers,"list",[actor])
		if listing.has("error"): return listing
		var dispatched := _call(helpers,"dispatch",[listing.value,request,pass_index])
		if dispatched.has("error"): return dispatched
		var summed := _sum(total,dispatched.value)
		if summed.has("error"): return summed
		total=summed.value
	if not request.has("attacker"): return {"error":"Missing hit attacker."}
	if request.attacker!=null:
		var kind := _call(helpers,"kind",[request.attacker])
		if kind.has("error"): return kind
		if not Numbers._integer(kind.value,255): return {"error":"Invalid hit attacker kind."}
		if int(kind.value)==1:
			if not Numbers._integer(request.get("mode"),255): return {"error":"Invalid hit mode."}
			var mode := int(request.mode)
			if mode in [1,2,5]:
				if mode==2 and not Numbers._integer(request.get("subtype"),255): return {"error":"Invalid hit subtype."}
				var event := 2 if mode==1 else 3 if mode==2 else 20
				var value := int(request.subtype) if mode==2 else 255
				var listing := _call(helpers,"list",[actor])
				if listing.has("error"): return listing
				var dispatched := _call(helpers,"event",[listing.value,event,value])
				if dispatched.has("error"): return dispatched
				var summed := _sum(total,dispatched.value)
				if summed.has("error"): return summed
				total=summed.value
	return {"state":actor,"request":request,"result":total}
