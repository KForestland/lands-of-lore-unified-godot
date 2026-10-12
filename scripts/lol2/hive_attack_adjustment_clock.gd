extends RefCounted
## Effect controller23819, routine7F3D3; source tick units, not seconds.
## Historical filename: this is NOT weapon controller23348 stat39C.
## Do not feed this effect counter into hive_weapon_request.from_controller.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func advance(context: Variant) -> Dictionary:
	if not context is Dictionary or not context.get("stop") is bool: return {"error":"Invalid attack adjustment context."}
	for field in ["timer","delta","value","limit","flags"]:
		var maximum := 262144 if field=="timer" else 524289 if field=="delta" else 255 if field=="flags" else 0x7ffffffc
		if not Numbers._integer(context.get(field),maximum): return {"error":"Unsupported attack adjustment field: "+field}
	var timer := int(context.timer)-int(context.delta)
	var value := int(context.value);var flags := int(context.flags)
	while timer<0:
		timer+=262144;value+=1
	if value>=int(context.limit):
		if context.stop: flags&=251
		else: value=0
	return {"timer":timer,"value":value,"flags":flags}

static func start(limit: Variant, flags42c: Variant, flags29c: Variant) -> Dictionary:
	for value in [limit,flags42c,flags29c]:
		if not Numbers._integer(value,255): return {"error":"Invalid attack adjustment start byte."}
	return {"timer":262144,"value":0,"limit":int(limit),"stop":false,"flags":int(flags29c)|4,"flags42c":int(flags42c)&251}

static func start_damage_shield(flags42c: Variant, flags29c: Variant) -> Dictionary:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_attack_adjustment_resource.json"))
	if not source is Dictionary or source.get("name")!="dam_sh.flc" or source.get("resource")!=469 or source.get("limit")!=16: return {"error":"Invalid damage-shield resource binding."}
	var state := start(int(source.limit),flags42c,flags29c)
	if not state.has("error"): state.resource=int(source.resource)
	return state
