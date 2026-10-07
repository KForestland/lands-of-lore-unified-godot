extends RefCounted
## A583E kind5 consumer / A821C pre-dispatch admission. The actor applies entry
## flags BEFORE positioning/effect construction, then finish_event AFTER return.
const Admission=preload("res://scripts/lol2/dawn_spell_admission.gd")
const Numbers=preload("res://scripts/lol2/hive_player_conditions.gd")

static func begin(context: Variant, frame_event: Variant, casting_enabled: Variant) -> Dictionary:
	if not frame_event is bool or not casting_enabled is bool or not context is Dictionary: return {"error":"Invalid cast event context."}
	var owner: Dictionary=context.duplicate(true)
	# Validation does not imply that the native gate actually calls admission.
	var checked:=Admission.admit(owner)
	if checked.has("error"): return checked
	if not frame_event or not casting_enabled:
		return {"checked":false,"admitted":false,"entry_flags":int(owner.b8),"stored_reason":int(owner.previous_reason),"supported_effect":false}
	owner.b8=int(owner.b8)&~0x40
	owner.check_cost=1;owner.write_reason=0
	var result:=Admission.admit(owner)
	return {"checked":true,"admitted":result.accepted,"entry_flags":result.b8,"stored_reason":result.stored_reason,
		"supported_effect":result.accepted and int(owner.spell)!=0}

static func finish_event(flags: Variant, frame_event: Variant) -> Dictionary:
	if not Numbers._integer(flags,0,4294967295) or not frame_event is bool: return {"error":"Invalid cast return flags."}
	# Rotate next selection even if the global casting gate or admission failed.
	return {"flags":int(flags)|0x80 if frame_event else int(flags)}
