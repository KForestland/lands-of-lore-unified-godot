extends RefCounted
## Source88FB0 request construction after reach and item callback admission.
## Numeric source fields remain explicit until equipment/global producers are bound.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func build(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid weapon request context."}
	for field in ["counter43","counter44","flags45"]:
		if not Numbers._integer(context.get(field),255): return {"error":"Invalid weapon request counter or flags."}
	for field in ["mask","signature"]:
		if not Numbers._integer(context.get(field),65535): return {"error":"Invalid weapon request definition."}
	if not context.get("stats") is Array or context.stats.size()!=4: return {"error":"Invalid weapon request stats."}
	for value in context.stats:
		if not Numbers._integer(value,0xffffffff): return {"error":"Invalid weapon request stat."}
	var bonus: Variant = context.get("signed_bonus")
	if not (bonus is int or bonus is float) or not is_finite(float(bonus)) or float(bonus)!=floor(float(bonus)) or bonus < -128 or bonus > 127: return {"error":"Invalid weapon request bonus."}
	var amount := int(bonus)
	for value in context.stats: amount+=int(value)
	var a := int(context.counter43);var b := int(context.counter44);var flags := int(context.flags45)
	var signature := int(context.signature);var callbacks := 0
	if b!=0:
		b-=1;signature|=64
		if b>0: callbacks=1
		elif a==0: flags|=32
	elif a!=0:
		a-=1;signature|=32
		if a>0: callbacks=1
		else: flags|=32
	return {"counter43":a,"counter44":b,"flags45":flags,"signature":signature,"mask":int(context.mask),"amount":amount&0xffffffff,"mode":1,"subtype":255,"callbacks":callbacks}

static func fine_longsword(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid Fine Longsword context."}
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_fine_longsword_request.json"))
	if not source is Dictionary or source.get("definition")!=5 or source.get("identity")!=0xe18240be or source.get("handler")!=0 or source.get("mask")!=2 or source.get("signature")!=4: return {"error":"Invalid Fine Longsword source properties."}
	var supplied: Dictionary = context.duplicate(true)
	supplied.mask=int(source.mask);supplied.signature=int(source.signature)
	return build(supplied)

static func restore_modifiers(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or int(saved.version)!=1: return {"error":"Invalid weapon modifier checkpoint."}
	var checkpoint := {"version":1}
	for field in ["counter43","counter44","flags45"]:
		if not Numbers._integer(saved.get(field),255): return {"error":"Invalid saved weapon modifier."}
		checkpoint[field]=int(saved[field])
	return {"checkpoint":checkpoint}

static func consume_fine_longsword(context: Variant, saved: Variant) -> Dictionary:
	var restored := restore_modifiers(saved)
	if restored.has("error"): return restored
	if not context is Dictionary: return {"error":"Invalid sword request context."}
	var supplied: Dictionary = context.duplicate(true)
	for field in ["counter43","counter44","flags45"]: supplied[field]=restored.checkpoint[field]
	var request := fine_longsword(supplied)
	if request.has("error"): return request
	for field in ["counter43","counter44","flags45"]: restored.checkpoint[field]=request[field]
	return {"request":request,"checkpoint":restored.checkpoint}

static func from_controller(controller: Variant, definition: Variant, modifiers: Variant) -> Dictionary:
	if not controller is Dictionary or not definition is Dictionary: return {"error":"Invalid weapon controller input."}
	var supplied := {"stats":[],"signed_bonus":controller.get("signed_bonus"),"mask":definition.get("mask"),"signature":definition.get("signature")}
	for field in ["attack","stat3a4","stat39c","stat3ac"]:
		var value: Variant = controller.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)) or value < -2147483648 or value > 4294967295: return {"error":"Invalid controller attack stat."}
		supplied.stats.append(int(value)&0xffffffff)
	var saved := restore_modifiers(modifiers)
	if saved.has("error"): return saved
	for field in ["counter43","counter44","flags45"]: supplied[field]=saved.checkpoint[field]
	return build(supplied)
