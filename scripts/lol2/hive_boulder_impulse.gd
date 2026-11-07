extends RefCounted
## Source111AD4: quantized sine table, fixed-point vector sum, bearing/magnitude.
## Four explicit rounding modes; the live game's FPU mode is not established.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const SOURCE_PI=3.1415926536
static func sine(angle: int) -> int:
	var wrapped:=angle&65535
	var index: int=(wrapped&32767)>>3
	return int(sin(float(index)*PI/4096.0)*65536.0)*(-1 if wrapped&32768 else 1)
static func combine(value: Variant) -> Dictionary:
	if not value is Dictionary: return {"error":"Invalid impulse context."}
	for key in ["angle","previous_angle"]:
		if not Values.integer(value.get(key),65535): return {"error":"Invalid impulse angle."}
	for key in ["impulse","previous_impulse"]:
		if not Values.integer(value.get(key),255<<16): return {"error":"Invalid impulse magnitude."}
	if not Values.integer(value.get("rounding_mode"),3): return {"error":"Invalid impulse rounding mode."}
	var angle:=int(value.angle);var previous:=int(value.previous_angle)
	var dx: int=((int(value.impulse)*sine(angle))>>16)+((int(value.previous_impulse)*sine(previous))>>16)
	var dy: int=((int(value.impulse)*sine(angle+16384))>>16)+((int(value.previous_impulse)*sine(previous+16384))>>16)
	var distance:=sqrt(float(dx)*float(dx)+float(dy)*float(dy))
	var length: int=roundi(distance) if int(value.rounding_mode)==0 else ceili(distance) if int(value.rounding_mode)==2 else floori(distance)
	var bearing: int=int((atan2(float(-dx),float(-dy))+SOURCE_PI)*32768.0/SOURCE_PI) if dx!=0 or dy!=0 else 0
	return {"bearing":bearing,"length":length,"stored_angle":bearing&65535,"stored_impulse":(length>>16)&255}
