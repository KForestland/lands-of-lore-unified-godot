extends RefCounted
## Source EXEC/spell32→player heading and mode-byte preprocessing; globals supplied.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Calculation = preload("res://scripts/lol2/hive_damage_calculation.gd")

@warning_ignore("integer_division")
static func prepare(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid damage preparation."}
	for field in ["attacker_heading","player_heading"]:
		if not Numbers._integer(context.get(field),65535): return {"error":"Invalid heading: "+field}
	if not Numbers._integer(context.get("guard"),4294967295) or not Numbers._integer(context.get("mode"),255): return {"error":"Invalid damage mode/guard."}
	if not Numbers._integer(context.get("amount"),127) or int(context.amount)<1: return {"error":"Unsupported incoming attack amount."}
	if not Numbers._integer(context.get("signature"),68) or int(context.signature) not in [4,36,68]: return {"error":"Unsupported incoming attack signature."}
	if int(context.signature)==4 and int(context.amount)!=10: return {"error":"Unsupported incoming spell amount."}
	var amount := int(context.amount);var signature := int(context.signature)
	var attacker_heading := int(context.attacker_heading);var player_heading := int(context.player_heading)
	var eligible := attacker_heading<=player_heading+8192 and attacker_heading>=((player_heading-8192)&0xffffffff) and int(context.guard)==0
	if eligible:
		amount+=amount/10;signature|=8
	if int(context.mode)==0 and amount>3: amount/=3
	elif int(context.mode)==2: amount*=2
	return {"amount":amount,"signature":signature,"heading_bonus":eligible}

static func resolve_attack(event: Variant, context: Variant) -> Dictionary:
	if not event is Dictionary or event.get("type")!="damage" or not Numbers._integer(event.get("mask"),65535) or int(event.mask)!=8: return {"error":"Unsupported damage request."}
	if not Numbers._integer(event.get("flags"),68) or int(event.flags) not in [36,68]: return {"error":"Unsupported melee signature."}
	if not context is Dictionary: return {"error":"Invalid target calculation context."}
	var supplied: Dictionary = context.duplicate(true)
	supplied.amount=event.get("amount");supplied.signature=event.get("flags")
	var prepared := prepare(supplied)
	if prepared.has("error"): return prepared
	supplied.amount=prepared.amount;supplied.signature=prepared.signature
	var result := Calculation.calculate(supplied)
	if result.has("error"): return result
	result.prepared=prepared
	return result

static func resolve_dawn_spell(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid spell target context."}
	var supplied: Dictionary = context.duplicate(true)
	# Original Dawn variant1 collision request, not caller-selectable spell data.
	supplied.amount=10;supplied.signature=4;supplied.damage_mask=256
	supplied.request_kind=2;supplied.request_tag=32;supplied.caster_factor=10
	var prepared := prepare(supplied)
	if prepared.has("error"): return prepared
	supplied.amount=prepared.amount;supplied.signature=prepared.signature
	var result := Calculation.calculate(supplied)
	if result.has("error"): return result
	result.prepared=prepared
	return result
