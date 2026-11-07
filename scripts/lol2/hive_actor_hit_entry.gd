extends RefCounted
## Initial virtual80 gates only; later status/mitigation admission remains separate.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func evaluate(actor: Variant, attacker_kind: Variant, self_hit: Variant) -> Dictionary:
	if not actor is Dictionary or not self_hit is bool: return {"error":"Invalid actor hit entry."}
	for field in ["a8","b5","b8"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid hit entry actor field."}
	if attacker_kind!=null and not Numbers._integer(attacker_kind,255): return {"error":"Invalid attacker kind."}
	if self_hit and attacker_kind==null: return {"error":"Self hit requires an attacker."}
	var state: Dictionary = actor.duplicate(true)
	for field in ["a8","b5","b8"]: state[field]=int(state[field])
	if state.a8==15:
		if attacker_kind!=null and int(attacker_kind)==32: state.b8|=4
		return {"state":state,"admitted":false}
	var admitted: bool = not self_hit and not ((state.b5&1)!=0 and attacker_kind!=null and int(attacker_kind)==2)
	return {"state":state,"admitted":admitted}

static func source_resists_status(status: Variant, mask: Variant) -> Dictionary:
	if not Numbers._integer(status,255) or not Numbers._integer(mask,65535): return {"error":"Invalid executioner status resistance input."}
	# A73F8 scans source operations10..5; EXEC operation7 has filter60h.
	return {"resists":int(status)==44 or (int(mask)&96)!=0}

static func adjust_resource(current: Variant, maximum: Variant, amount: Variant) -> Dictionary:
	if not Numbers._integer(current,65535) or not Numbers._integer(maximum,65535): return {"error":"Invalid actor resource."}
	if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)!=floor(float(amount)) or amount < -2147483648 or amount > 2147483647: return {"error":"Invalid resource adjustment."}
	# Virtual94 at A7C34: signed32 addition, then clamp against actor wordB2.
	var total := (int(current)+int(amount))&0xffffffff
	if total>=0x80000000: total-=0x100000000
	return {"current":mini(int(maximum),maxi(0,total))}

static func prepare_calculation(actor: Variant, definition83: Variant) -> Dictionary:
	# A6C2B after earlier admission/status checks; false direct_calculation requires alternate mitigation.
	if not actor is Dictionary or not Numbers._integer(definition83,255): return {"error":"Invalid actor hit calculation input."}
	for field in ["b4","b5","b7","byte91","a7"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid actor calculation field: "+field}
	if not Numbers._integer(actor.get("word70"),0xffffffff) or not Numbers._integer(actor.get("health"),65535): return {"error":"Invalid actor hit word."}
	var state: Dictionary = actor.duplicate(true)
	for field in ["b4","b5","b7","byte91","a7","word70","health"]: state[field]=int(state[field])
	state.b4&=252
	if (state.word70&15)==1: state.b5|=12
	return {"state":state,"direct_calculation":state.byte91==0 and (state.b7&6)==0,"current":state.health,"remaining":state.health,"scale":maxi(int(definition83),1),"scalar":state.a7}

static func status_descriptor(status: Variant) -> Dictionary:
	if not Numbers._integer(status,255): return {"error":"Invalid hit status."}
	var definitions := {39:[5,0,4],40:[5,0,2],41:[7,0,4],42:[5,113,1],43:[7,113,1],44:[7,0,103],61:[7,0,1]}
	return {"descriptor":definitions.get(int(status),[0,0,0]).duplicate()}

static func extra_mitigation(status: Variant, b7: Variant, signature: Variant) -> Dictionary:
	var selected := status_descriptor(status)
	if selected.has("error"): return selected
	if not Numbers._integer(b7,255) or not Numbers._integer(signature,65535): return {"error":"Invalid alternate mitigation flags."}
	var descriptor: Array = [selected.descriptor,[0,0,0],[0,0,0],[0,0,0]]
	var index := 1 if int(status)!=0 else 0
	var branch := (int(b7)>>1)&3
	var flags := int(signature)
	if branch==1:
		flags|=8
		if int(status)==0: return {"descriptor":null,"signature":flags}
	elif branch==2:
		descriptor[index]=[4,2517,119];descriptor[index+1]=[7,5674,119]
	elif branch==3:
		descriptor[index]=[2,2340,119];descriptor[index+1]=[7,5851,119]
	return {"descriptor":descriptor,"signature":flags}

static func sword_status_entry(actor: Variant, signature: Variant) -> Dictionary:
	if not actor is Dictionary or not Numbers._integer(actor.get("byte91"),255) or not Numbers._integer(actor.get("b6"),255): return {"error":"Invalid sword status actor."}
	if not Numbers._integer(signature,68) or int(signature) not in [4,36,68]: return {"error":"Unsupported sword entry signature."}
	var state: Dictionary = actor.duplicate(true)
	state.byte91=int(state.byte91);state.b6=int(state.b6)
	var reset: bool = state.byte91==61 and (state.b6&4)==0
	if state.byte91==61: state.b6|=4
	# Exact EXEC definition resists both signature20h and40h status branches.
	# Caller must stage the source1071C8 clear of globalDF67C when requested.
	return {"state":state,"clear_df67c":reset}
