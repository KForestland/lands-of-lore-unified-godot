extends RefCounted
## Player→actor preprocessing. Mode is the source global byte, not a UI setting.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
@warning_ignore("integer_division")
static func prepare(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid actor damage preparation."}
	for field in ["attacker_heading","target_heading"]:
		if not Numbers._integer(context.get(field),65535): return {"error":"Invalid actor hit heading."}
	if not Numbers._integer(context.get("mode"),255): return {"error":"Invalid actor damage mode."}
	if not Numbers._integer(context.get("amount"),127) or int(context.amount)<1: return {"error":"Unsupported actor hit amount."}
	var damage_mask: Variant = context.get("damage_mask",8)
	if not Numbers._integer(damage_mask,8) or int(damage_mask) not in [2,8]: return {"error":"Unsupported actor damage mask."}
	var signatures: Array = [4,36,68] if int(damage_mask)==2 else [36,68]
	if not Numbers._integer(context.get("signature"),68) or int(context.signature) not in signatures: return {"error":"Unsupported actor hit signature."}
	var amount := int(context.amount);var signature := int(context.signature)
	var target := int(context.target_heading);var attacker := int(context.attacker_heading)
	var eligible := attacker<=target+8192 and attacker>=((target-8192)&0xffffffff)
	if eligible: amount+=amount/10;signature|=8
	if int(context.mode)==0: amount*=2
	elif int(context.mode)==2 and amount>2: amount/=2
	return {"amount":amount,"signature":signature,"heading_bonus":eligible}

static func calculate(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid executioner mitigation context."}
	var supplied: Dictionary = context.duplicate(true)
	# Original EXEC definition's first20 bytes, verified by actor mitigation replay.
	supplied.descriptors=[[[7,0,96],[7,1552,0],[5,2,0],[3,1,3]]]
	return preload("res://scripts/lol2/hive_damage_calculation.gd").calculate(supplied)

static func resolve(context: Variant) -> Dictionary:
	var prepared := prepare(context)
	if prepared.has("error"): return prepared
	var supplied: Dictionary = context.duplicate(true)
	supplied.amount=prepared.amount;supplied.signature=prepared.signature
	var result := calculate(supplied)
	if not result.has("error"): result.prepared=prepared
	return result

static func calculate_alternate(context: Variant, status: Variant, b7: Variant) -> Dictionary:
	# Amount has already passed heading/mode preparation. This API also accepts
	# the pre-bit8 signature so the alternate branch's signature write is retained.
	if not context is Dictionary: return {"error":"Invalid alternate actor damage context."}
	var extra := preload("res://scripts/lol2/hive_actor_hit_entry.gd").extra_mitigation(status,b7,context.get("signature"))
	if extra.has("error"): return extra
	var supplied: Dictionary = context.duplicate(true)
	supplied.signature=extra.signature
	supplied.descriptors=[[[7,0,96],[7,1552,0],[5,2,0],[3,1,3]]]
	if extra.descriptor!=null: supplied.descriptors.append(extra.descriptor)
	return preload("res://scripts/lol2/hive_damage_calculation.gd").calculate(supplied)

static func prepare_sword_hit(actor: Variant, context: Variant, definition83: Variant) -> Dictionary:
	# Player→original EXEC only. Caller supplies an already-built sword request.
	# Returns staged actor/effects and damage; it does not execute later feedback.
	if not context is Dictionary: return {"error":"Invalid sword hit context."}
	var entry_type = preload("res://scripts/lol2/hive_actor_hit_entry.gd")
	var entry: Dictionary = entry_type.evaluate(actor,1,false)
	if entry.has("error"): return entry
	if not entry.admitted: return {"state":entry.state,"admitted":false,"clear_df67c":false}
	var status: Dictionary = entry_type.sword_status_entry(entry.state,context.get("signature"))
	if status.has("error"): return status
	var handoff: Dictionary = entry_type.prepare_calculation(status.state,definition83)
	if handoff.has("error"): return handoff
	var supplied: Dictionary = context.duplicate(true)
	supplied.damage_mask=2;supplied.current=handoff.current;supplied.scalar=handoff.scalar
	var extra: Variant = null
	if not handoff.direct_calculation:
		var modifiers: Dictionary = entry_type.extra_mitigation(handoff.state.byte91,handoff.state.b7,supplied.signature)
		if modifiers.has("error"): return modifiers
		supplied.signature=modifiers.signature;extra=modifiers.descriptor
	# The alternate branch can set bit8 before heading/mode preparation.
	var incoming_flags := int(supplied.signature)
	supplied.signature=incoming_flags&~8
	var prepared := prepare(supplied)
	if prepared.has("error"): return prepared
	prepared.signature|=incoming_flags&8
	supplied.amount=prepared.amount;supplied.signature=prepared.signature
	supplied.descriptors=[[[7,0,96],[7,1552,0],[5,2,0],[3,1,3]]]
	if extra!=null: supplied.descriptors.append(extra)
	var damage := preload("res://scripts/lol2/hive_damage_calculation.gd").calculate(supplied)
	if damage.has("error"): return damage
	return {"state":handoff.state,"admitted":true,"clear_df67c":status.clear_df67c,"damage":damage,"prepared":prepared,"scale":handoff.scale}
