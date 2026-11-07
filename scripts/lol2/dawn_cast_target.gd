extends RefCounted
## Native A8270..A839C for a non-null target. Virtual/helper results supplied;
## neither the targetless branch nor effect construction is implemented here.
const Heading=preload("res://scripts/lol2/dawn_heading.gd")
static func integer(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v==floor(float(v)) and v>=lo and v<=hi
static func signed32(v: int) -> int: return ((v+2147483648)&0xffffffff)-2147483648
static func prepare(context: Variant, bearing: Variant) -> Dictionary:
	if not context is Dictionary or not integer(bearing,0,255): return {"error":"Invalid cast target context."}
	for pair in [["flags",0,4294967295],["b4",0,4294967295],["target",1,4294967295],["distance",-2147483648,2147483647],["radius",0,255],["kind",0,255],["rng",0,63],["height",0,255],["heading",0,65535]]:
		if not integer(context.get(pair[0]),pair[1],pair[2]): return {"error":"Invalid cast target field: "+pair[0]}
	for field in ["actor","position","remembered"]:
		var v=context.get(field)
		if not v is Array or v.size()!=3: return {"error":"Invalid cast target coordinates."}
		for component in v:
			if not integer(component,-2147483648,2147483647): return {"error":"Invalid cast target coordinate."}
	var flags:=int(context.flags)
	if (flags&0x40)!=0 and signed32(int(context.distance)-(int(context.radius)<<16))<0: flags&=~0x40
	var b4:=int(context.b4)
	var indirect: bool=(flags&0x40)!=0
	var special: bool=not indirect and (b4&0x20000)!=0 and int(context.kind)==5
	var position: Array=(context.remembered if indirect else context.position).duplicate()
	position=position.map(func(v):return int(v))
	# Original always overwrites Z using current target position and virtual EC.
	position[2]=signed32(int(context.position[2])+(int(context.height)<<16))
	if indirect: b4=(b4&~0x8000000)|((int(context.rng)>>5)<<27)
	return {"position":position,"b4":b4,"flags":flags,"direct_target":0 if indirect or special else int(context.target),
		"alternate_binding":"remembered" if indirect else "object" if special else "none",
		"saved_heading":int(context.heading),"heading":int(bearing)<<8,"rng_requested":indirect}

static func prepare_with_heading(context: Variant) -> Dictionary:
	var result:=prepare(context,0)
	if result.has("error"): return result
	var h:=Heading.between([context.actor[0],context.actor[1]],[result.position[0],result.position[1]])
	if h.has("error"): return h
	result.heading=h.word
	return result

## A83B6..A846B: targetless casts project forward from the caster. Quantized
## table values are supplied by the caller; runtime table initialization unbound.
static func without_target(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid targetless cast context."}
	var position=context.get("position")
	if not position is Array or position.size()!=3: return {"error":"Invalid caster position."}
	for v in position:
		if not integer(v,-2147483648,2147483647): return {"error":"Invalid caster coordinate."}
	for pair in [["heading",0,65535],["radius",0,255],["height",0,255],["sine",-65536,65536],["cosine",-65536,65536]]:
		if not integer(context.get(pair[0]),pair[1],pair[2]): return {"error":"Invalid targetless field: "+pair[0]}
	var radius:=int(context.radius)
	return {"position":[signed32(int(position[0])+radius*int(context.sine)),signed32(int(position[1])+radius*int(context.cosine)),signed32(int(position[2])+(int(context.height)<<16))],
		"direct_target":0,"alternate_binding":"local","heading":int(context.heading),"rng_requested":false}
