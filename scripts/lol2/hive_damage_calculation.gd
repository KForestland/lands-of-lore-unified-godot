extends RefCounted
## Native EXEC8, sword2, boulder256 and Dawn spell32; bounded signatures.
## Input amount is already adjusted by the upstream heading/difficulty stage.
const Numbers = preload("res://scripts/lol2/save_value_rules.gd")

@warning_ignore("integer_division")
static func calculate(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid damage context."}
	if not Numbers.integer(context.get("amount"),278) or int(context.amount)<1: return {"error":"Unsupported adjusted attack amount."}
	if not Numbers.integer(context.get("scalar"),65535) or not Numbers.integer(context.get("current"),1000000): return {"error":"Unsupported scalar/current value."}
	var damage_mask: Variant = context.get("damage_mask",8)
	if not Numbers.integer(damage_mask,256) or int(damage_mask) not in [2,8,256]: return {"error":"Unsupported damage mask."}
	var signatures: Array = [4,12,28] if int(damage_mask)==256 else [4,12,36,44,68,76] if int(damage_mask)==2 else [36,68,44,76]
	if not Numbers.integer(context.get("signature"),76) or int(context.signature) not in signatures: return {"error":"Unsupported attack signature."}
	var dawn_spell := int(damage_mask)==256 and int(context.signature) in [4,12]
	if dawn_spell:
		# This entry is verified for Dawn's mode2/effect32 request only.
		for pair in [["request_kind",2],["request_tag",32],["caster_factor",10]]:
			if not Numbers.integer(context.get(pair[0]),int(pair[1])) or int(context[pair[0]])!=int(pair[1]): return {"error":"Unsupported spell damage request."}
		var amounts: Array = [3,10,20] if int(context.signature)==4 else [3,11,22]
		if int(context.amount) not in amounts or int(context.scalar)>128: return {"error":"Unsupported spell scaling input."}
		if not Numbers.integer(context.get("player_magic_level"),30) or int(context.player_magic_level)<1: return {"error":"Invalid spell target magic level."}
	if not context.get("descriptors") is Array or context.descriptors.size()>8: return {"error":"Invalid mitigation list."}
	for descriptor in context.descriptors:
		if not descriptor is Array or descriptor.size()>4: return {"error":"Invalid mitigation descriptor."}
		for entry in descriptor:
			if not entry is Array or entry.size()!=3: return {"error":"Invalid mitigation slot."}
			if not Numbers.integer(entry[0],255) or not Numbers.integer(entry[1],65535) or not Numbers.integer(entry[2],65535): return {"error":"Invalid mitigation operation/filter."}
	var amount := int(context.amount);var scalar := int(context.scalar);var signature := int(context.signature)
	var ratio: int = amount*32768/maxi(scalar,1) if scalar>=amount else 65536-scalar*32768/amount
	var component: int = amount*(65536 if (signature&8)!=0 else ratio)
	if dawn_spell:
		component=(amount*65536)*int(context.caster_factor)/int(context.player_magic_level)
		if component>amount*65536: component-=(component-amount*65536)*scalar/256
	if (signature&~28)!=0: component/=2
	if component==0: component=32768
	var total := 0;var mask := int(damage_mask);var flags := signature;var calls: Array[int] = []
	var components: Array = [4,signature&~28] if (signature&~28)!=0 else [4]
	for bit in components:
		var value := component
		for descriptor in context.descriptors:
			var canceled := false
			for entry in descriptor:
				var op := int(entry[0]);var damage := int(entry[1]);var filter_flags := int(entry[2])
				if (damage!=0 and (damage&int(damage_mask))==0) or (filter_flags!=0 and (filter_flags&bit)==0): continue
				# Native flag0x10 is a reduction override, not a damage component.
				if (signature&16)!=0 and (filter_flags&16)==0 and op in [5,6,7,10]: continue
				if op in [2,3,4]: value*=op
				elif op==5: value/=2
				elif op==6: value=value*3/4
				elif op==10: value/=4
				elif op==7:
					value=0;mask=0;flags&=~bit;canceled=true
				elif op in [8,9]:
					calls.append(((value/2 if op==8 else value)+65535)/65536);value=0
				# Keep every intermediate in the nonnegative native domain verified.
				if value>0x1fffffff: return {"error":"Mitigation exceeds verified arithmetic range."}
				if canceled: break
			if canceled: break
		total+=value
	if total>0x7fff0000: return {"error":"Damage exceeds verified finalization range."}
	var current := int(context.current)
	var loss := mini(current,(total+65535)/65536)
	return {"fixed":total,"loss":loss,"remaining":current-loss,"percentage":100*loss/current if current!=0 else 100,"mask":mask,"flags":flags,"virtual84":calls}
