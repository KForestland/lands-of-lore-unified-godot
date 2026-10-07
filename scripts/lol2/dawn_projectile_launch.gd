extends RefCounted
## AF4A8 launch placement with a supplied bearing and world-query outcomes.
## The world owner must resolve placement at each requested point in order.
## Targeted launch uses the source atan formula, distinct from integer cast heading.
const Target=preload("res://scripts/lol2/dawn_cast_target.gd")
static func signed32(value: int) -> int:
	value&=0xffffffff
	return value-0x100000000 if value>=0x80000000 else value

## AF50B..AF596. Original constants and signed32 endpoint differences.
## Native x87 and host double agree on the checked fixture; universal last-bit
## equivalence is not asserted across every input/platform.
static func bearing(first: Variant, second: Variant) -> Dictionary:
	for point in [first,second]:
		if not point is Array or point.size()!=2: return {"error":"Invalid bearing point."}
		for coordinate in point:
			if not Target.integer(coordinate,-2147483648,2147483647): return {"error":"Invalid bearing coordinate."}
	var dx:=signed32(int(first[0])-int(second[0]))
	var dy:=signed32(int(first[1])-int(second[1]))
	var angle:=0
	if dx!=0 or dy!=0:
		angle=int((atan2(float(dx),float(dy))+3.1415926536)*32768.0/3.1415926536)
	return {"bearing":angle,"word":angle&65535}

static func plan(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid projectile launch context."}
	for field in ["heading","initial_heading","initial_speed"]:
		if not Target.integer(context.get(field),0,65535): return {"error":"Invalid launch word: "+field}
	for field in ["sprite_height","owner_radius","effect_radius","speed"]:
		if not Target.integer(context.get(field),0,255): return {"error":"Invalid launch byte: "+field}
	if not Target.integer(context.get("height"),-32768,32767) or not Target.integer(context.get("flags"),0,0xffffffff): return {"error":"Invalid launch height/flags."}
	if not context.get("position") is Array or context.position.size()!=2: return {"error":"Invalid launch position."}
	for coordinate in context.position:
		if not Target.integer(coordinate,-2147483648,2147483647): return {"error":"Invalid launch coordinate."}
	for field in ["sine","cosine"]:
		if not Target.integer(context.get(field),-65536,65536): return {"error":"Invalid launch rotation."}
	if not context.get("collision") is bool or not context.get("placements") is Array or context.placements.size()!=2: return {"error":"Invalid launch query results."}
	for placed in context.placements:
		if not placed is bool: return {"error":"Invalid launch placement result."}
	var origin: Array=[int(context.position[0]),int(context.position[1]),signed32((int(context.height)-(int(context.sprite_height)>>1))<<16)]
	var radius: int=int(context.owner_radius)+int(context.effect_radius)+1
	var projected: Array=[signed32(origin[0]+radius*int(context.sine)),signed32(origin[1]+radius*int(context.cosine)),origin[2]]
	var requests: Array=[projected.duplicate()]
	var position: Array=projected
	var placed: bool=context.placements[0]
	if not placed:
		position=origin
		requests.append(origin.duplicate())
		placed=context.placements[1]
	return {"position":position,"placement_requests":requests,
		"heading":int(context.heading) if placed else int(context.initial_heading),
		"speed":int(context.speed) if placed else int(context.initial_speed),
		"flags":int(context.flags)|0x08200000 if placed else int(context.flags),
		"accepted":placed and not context.collision}
