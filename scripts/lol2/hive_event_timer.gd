extends RefCounted
## Kind2 flags10h timer arithmetic; caller owns RNG, registration and group execution.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func restore(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or int(saved.version)!=1: return {"error":"Invalid Hive event timer version."}
	if not Numbers._integer(saved.get("flags"),255) or not Numbers._integer(saved.get("remaining"),65535): return {"error":"Invalid Hive event timer state."}
	return {"checkpoint":{"version":1,"flags":int(saved.flags),"remaining":int(saved.remaining)}}
static func advance(saved: Variant, elapsed: Variant, reload_value: Variant) -> Dictionary:
	var checked := restore(saved)
	if checked.has("error"): return checked
	var state: Dictionary = checked.checkpoint
	if (state.flags&1)!=0: return {"checkpoint":state,"fired":false}
	if not Numbers._integer(elapsed,4294967295): return {"error":"Invalid native timer elapsed value."}
	if state.remaining>int(elapsed):
		state.remaining-=int(elapsed)
		return {"checkpoint":state,"fired":false}
	if not Numbers._integer(reload_value,65535): return {"error":"Missing native timer reload."}
	state.remaining=state.remaining+int(reload_value)-int(elapsed) if int(reload_value)>int(elapsed) else 0
	return {"checkpoint":state,"fired":true}
static func stop(saved: Variant) -> Dictionary:
	var checked := restore(saved)
	if checked.has("error"): return checked
	var state: Dictionary = checked.checkpoint
	var unregister: bool = (state.flags&1)==0 and (state.flags&128)!=0
	if (state.flags&1)==0: state.flags=(state.flags&127)|1
	return {"checkpoint":state,"unregister":unregister}
static func reset(saved: Variant, reload_value: Variant) -> Dictionary:
	var checked := restore(saved)
	if checked.has("error"): return checked
	if not Numbers._integer(reload_value,65535): return {"error":"Invalid native timer reload."}
	checked.checkpoint.remaining=int(reload_value)
	return checked

static func draw_reload(seed: Variant, lower: Variant, upper: Variant, scale: Variant) -> Dictionary:
	if not Numbers._integer(seed,4294967295) or not Numbers._integer(lower,255) or not Numbers._integer(upper,255) or not Numbers._integer(scale,65535): return {"error":"Invalid native timer random inputs."}
	var lo := mini(int(lower),int(upper))
	var hi := maxi(int(lower),int(upper))
	var rng := int(seed)
	var draw := lo
	if lo!=hi:
		var width := hi-lo
		var mask := 1
		while mask<width: mask=(mask<<1)|1
		while true:
			rng=(rng*0x41c64e6d+0x3039)&0xffffffff
			var candidate := ((rng>>10)&0x7fff)&mask
			if candidate<=width:
				draw=lo+candidate
				break
	return {"rng":rng,"draw":draw,"reload":(draw*int(scale))&65535}

static func advance_with_rng(saved: Variant, elapsed: Variant, seed: Variant, lower: Variant, upper: Variant, scale: Variant) -> Dictionary:
	var checked := restore(saved)
	if checked.has("error"): return checked
	if not Numbers._integer(seed,4294967295): return {"error":"Invalid native timer RNG state."}
	if (int(checked.checkpoint.flags)&1)!=0:
		return {"checkpoint":checked.checkpoint,"fired":false,"rng":int(seed)}
	if not Numbers._integer(elapsed,4294967295): return {"error":"Invalid native timer elapsed value."}
	if int(checked.checkpoint.remaining)>int(elapsed):
		var waiting := advance(checked.checkpoint,elapsed,null)
		waiting.rng=int(seed)
		return waiting
	var drawn := draw_reload(seed,lower,upper,scale)
	if drawn.has("error"): return drawn
	var result := advance(checked.checkpoint,elapsed,drawn.reload)
	result.rng=drawn.rng
	return result
