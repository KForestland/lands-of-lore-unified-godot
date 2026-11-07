extends RefCounted
## A9A94 perception stages. Live geometry and the remaining channels are external.
const Spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func region_value(counter20e: Variant, stamp2a: Variant) -> Dictionary:
	if not Numbers._integer(counter20e,4294967295) or not Numbers._integer(stamp2a,65535): return {"error":"Invalid perception counter/stamp."}
	return {"value":0x7fffffff if int(stamp2a)==0 else (int(counter20e)-int(stamp2a))&65535}

static func player_level(thresholds: Variant, value6c: Variant) -> Dictionary:
	if not thresholds is Array or thresholds.size()!=5 or not Numbers._integer(value6c,4294967295): return {"error":"Invalid player perception thresholds/value."}
	for threshold in thresholds:
		if not Numbers._integer(threshold,4294967295): return {"error":"Invalid player perception threshold."}
	if int(value6c)!=0:
		for i in range(4,-1,-1):
			if int(value6c)<=int(thresholds[i]): return {"value":(i+1)*51}
	return {"value":0}

static func evaluate_player(actor: Variant, context: Variant) -> Dictionary:
	if not actor is Dictionary or not context is Dictionary or not context.get("region_present") is bool: return {"error":"Invalid player perception entry."}
	if not Numbers._integer(actor.get("byte9c"),255): return {"error":"Missing prior player perception."}
	var state: Dictionary = actor.duplicate(true)
	state.byte9c=0
	if not context.region_present: return {"state":state,"result":0,"calls":[]}
	if not context.get("concealed") is bool: return {"error":"Missing player concealment gate."}
	var measured := distance_gate(actor.byte9c,context.get("distance"),context.get("z"),context.get("target_z"),context.get("near_range"),context.get("falloff"))
	if measured.has("error"): return measured
	var calls: Array = ["distance"]
	var flags := 0
	var facing := false
	var cached := false
	if not measured.in_range: state.byte61=0
	elif not context.concealed:
		var first_context: Dictionary = context.duplicate(true)
		if context.has("points"):
			var bearing_result := Spatial.bearing(context.points)
			if bearing_result.has("error"): return bearing_result
			first_context.bearing=bearing_result.bearing
		first_context.whole=measured.whole;first_context.prior=actor.byte9c
		first_context.byte61=state.get("byte61");first_context.player=true
		var first := facing_channel(first_context)
		if first.has("error"): return first
		calls.append("bearing")
		facing=first.facing;cached=first.queried;flags=first.flags;state.byte61=first.byte61
		if cached: calls.append("visibility")
	var middle_context: Dictionary = context.duplicate(true)
	middle_context.whole=measured.whole;middle_context.flags=flags;middle_context.cached=cached
	if context.has("player_fields"):
		if not context.player_fields is Dictionary: return {"error":"Invalid player perception fields."}
		var region_result := region_value(context.player_fields.get("counter20e"),context.get("region_stamp"))
		if region_result.has("error"): return region_result
		middle_context.region_value=region_result.value
		var ranges: Variant = context.get("ranges")
		if not ranges is Array or ranges.size()!=6: return {"error":"Six perception range fields required."}
		for i in range(2,6):
			if not Numbers._integer(ranges[i],65535): return {"error":"Invalid perception definition range."}
		if measured.whole<=int(ranges[2])+int(ranges[3]) or measured.whole<=int(ranges[4])+int(ranges[5]):
			var level := player_level(context.player_fields.get("thresholds"),actor.get("word6c"))
			if level.has("error"): return level
			middle_context.level55=level.value;middle_context.level51=level.value
	var middle := player_channels(state,middle_context)
	if middle.has("error"): return middle
	calls.append("region");calls.append_array(middle.calls)
	var finished := finish_player(middle.state,middle.flags,facing)
	if finished.has("error"): return finished
	finished.state.byte9c=int(middle.flags)
	return {"state":finished.state,"result":1,"calls":calls}

static func player_channels(actor: Variant, context: Variant) -> Dictionary:
	if not actor is Dictionary or not context is Dictionary: return {"error":"Invalid player perception channels."}
	for field in ["byte60","byte5f","byte5a","b7"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid perception actor field: "+field}
	if not Spatial._signed(context.get("whole")) or not Numbers._integer(context.get("flags"),255) or not Numbers._integer(context.get("region_value"),4294967295) or not context.get("cached") is bool:
		return {"error":"Invalid perception channel inputs."}
	var ranges: Variant = context.get("ranges")
	if not ranges is Array or ranges.size()!=6: return {"error":"Six perception range fields required."}
	for i in range(6):
		if not Numbers._integer(ranges[i],255 if i<2 else 65535): return {"error":"Invalid perception definition range."}
	var state: Dictionary = actor.duplicate(true)
	var flags := int(context.flags)
	var calls: Array = []
	var strength := 0
	var value := int(context.region_value)
	if value<int(ranges[0])+int(ranges[1]):
		strength=255 if value<=int(ranges[0]) else (value-int(ranges[0]))*255/int(ranges[1])
	if strength!=0:
		state.byte60=maxi(int(actor.byte60),strength)&255
		flags|=32
	for channel in range(2):
		var near_range := int(ranges[2+channel*2])
		var falloff := int(ranges[3+channel*2])
		strength=0
		if int(context.whole)<=near_range+falloff:
			var level: Variant = context.get("level55" if channel==0 else "level51")
			if not Numbers._integer(level,4294967295): return {"error":"Missing player perception level."}
			calls.append("level")
			strength=int(level)&255
			var excess := int(context.whole)-near_range
			if excess>0:
				strength=strength*(falloff-excess)/falloff
				if channel==0: flags|=128
			elif channel==0 and strength>127:
				if not Numbers._integer(context.get("visibility"),4294967295): return {"error":"Missing player perception visibility."}
				if not context.cached: calls.append("visibility")
				if int(context.visibility)!=0:
					flags|=68;state.b7=int(state.b7)|8
		var field := "byte5f" if channel==0 else "byte5a"
		if strength!=0:
			state[field]=maxi(int(state[field]),strength)&255
			flags|=8 if channel==0 else 16
		elif channel==0 and int(state.byte5f)<127: state.b7=int(state.b7)&247
	return {"state":state,"flags":flags,"calls":calls}

static func finish_player(actor: Variant, flags: Variant, facing: Variant) -> Dictionary:
	if not actor is Dictionary or not Numbers._integer(flags,255) or not facing is bool: return {"error":"Invalid completed perception."}
	for field in ["b4","b5","byte51","byte52","byte61"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid perception actor field: "+field}
	if not Numbers._integer(actor.get("word70"),4294967295): return {"error":"Invalid perception actor mode."}
	var state: Dictionary = actor.duplicate(true)
	if int(flags)==0:
		state.byte51=0
		if int(actor.byte52)==0: state.byte52=1
	else:
		if (int(actor.word70)&15)==2: state.b5=int(actor.b5)|12
		var special: bool = (int(actor.b4)&64)!=0 and facing
		if int(actor.byte61)==255 and special: state.byte51=255
		elif int(actor.byte61)<int(actor.byte51): state.byte51=int(actor.byte61)
		elif int(actor.byte51)==255 and not special: state.byte51=254
		state.byte52=0
	return {"state":state}

static func distance_gate(prior: Variant, distance: Variant, z: Variant, target_z: Variant, near_range: Variant, falloff: Variant) -> Dictionary:
	if not Numbers._integer(prior,255) or not Numbers._integer(near_range,65535) or not Numbers._integer(falloff,65535): return {"error":"Invalid perception range/history."}
	for value in [distance,z,target_z]:
		if not Spatial._signed(value): return {"error":"Invalid perception position/distance."}
	var whole := int(distance)>>16
	if (int(prior)&7)==0:
		var separation := Spatial._i32(int(z)-int(target_z))
		if separation<0: separation=Spatial._i32(-separation)
		whole=Spatial._i32(whole+(separation>>16))
	return {"whole":whole,"in_range":int(near_range)+int(falloff)>=whole}

static func facing_channel(context: Variant) -> Dictionary:
	# Called after the first range gate and player concealment gate have passed.
	if not context is Dictionary: return {"error":"Invalid perception facing context."}
	for field in ["heading","angle","near_range","falloff"]:
		if not Numbers._integer(context.get(field),65535): return {"error":"Invalid perception field: "+field}
	for field in ["bearing","prior","byte61"]:
		if not Numbers._integer(context.get(field),255): return {"error":"Invalid perception field: "+field}
	if not context.get("player") is bool or not Spatial._signed(context.get("whole")): return {"error":"Invalid perception mode/distance."}
	if int(context.whole)>int(context.near_range)+int(context.falloff): return {"error":"Perception range gate has not passed."}
	var difference := (int(context.heading)-(int(context.bearing)<<8))&65535
	var folded := difference if difference<=32767 else 65535-difference
	var facing := folded<=int(context.angle)/2
	var result := {"facing":facing,"queried":false,"flags":0,"byte61":int(context.byte61),"strength":null}
	if not facing and (int(context.prior)&7)==0: return result
	var excess := int(context.whole)-int(context.near_range)
	var strength := 255
	result.flags=64
	if excess>0:
		if int(context.falloff)==0: return {"error":"Zero perception falloff divisor."}
		strength=255-(excess*256/int(context.falloff))
		result.flags=128
	result.strength=strength
	if strength==0: return result
	if not Numbers._integer(context.get("visibility"),4294967295): return {"error":"Missing region visibility result."}
	result.queried=true
	if int(context.visibility)!=0:
		result.flags=int(result.flags)|(3 if strength==255 else 2)
		if context.player: result.byte61=strength&255
	return result
