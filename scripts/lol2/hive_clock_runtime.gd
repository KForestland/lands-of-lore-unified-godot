extends RefCounted
## Controller E0BE9: native timer samples -> animation delta and status gate.
## Wall-clock conversion and live scheduling belong to the caller.

static func initial_state() -> Dictionary:
	return {"samples":[0,0,0,0],"cursor":0,"fraction8":0,"fraction16":0,"status_accum":0,"seconds":0}

static func _integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= 0 and value <= maximum

static func advance_native(state: Variant, elapsed_ticks: Variant, running: bool = true) -> Dictionary:
	if not state is Dictionary or not _integer(elapsed_ticks,2147483647):
		return {"error":"Invalid native clock input."}
	if not state.get("samples") is Array or state.samples.size() != 4:
		return {"error":"Clock requires four timer samples."}
	for sample in state.samples:
		if not _integer(sample,480): return {"error":"Invalid timer sample."}
	for field in {"cursor":3,"fraction8":255,"fraction16":65535,"status_accum":3932159,"seconds":59}:
		var maximum: int = {"cursor":3,"fraction8":255,"fraction16":65535,"status_accum":3932159,"seconds":59}[field]
		if not _integer(state.get(field),maximum): return {"error":"Invalid clock field: "+field}
	if not running:
		return {"state":state.duplicate(true),"advanced":false,"delta":0,"elapsed":0,"fixed":0,"status_gate":false,"minute_gate":false}
	var next: Dictionary = state.duplicate(true)
	next.samples[int(state.cursor)] = mini(int(elapsed_ticks),480)
	next.cursor = (int(state.cursor)+1)%4
	var sum := 0
	for sample in next.samples: sum += int(sample)
	var fixed := mini(sum*2048,524288)
	var total8 := fixed+int(state.fraction8)
	var total16 := fixed+int(state.fraction16)
	next.fraction8 = total8 & 255
	next.fraction16 = total16 & 65535
	var status := int(state.status_accum)+fixed
	var gate := status >= 3932160
	next.status_accum = status % 3932160
	next.seconds = (int(state.seconds)+int(gate))%60
	return {"state":next,"advanced":true,"delta":total8>>8,"elapsed":total16>>16,"fixed":fixed,"status_gate":gate,"minute_gate":gate and next.seconds == 0}

## Verified DOSBox reference: PIT input1193182, divisor2485; animation slot
## increment65536 produces one timer tick per interrupt. Phase continues during
## pause, while the controller does not consume samples or accumulate catch-up.
static func advance_reference_time(state: Variant, microseconds: Variant, phase: Variant, running: bool = true) -> Dictionary:
	const PERIOD = 2485 * 1000000
	if not _integer(microseconds,3600000000) or not _integer(phase,PERIOD-1):
		return {"error":"Invalid reference clock time or phase."}
	var scaled := int(phase)+int(microseconds)*1193182
	var ticks: int = scaled / PERIOD
	var result := advance_native(state,ticks,running)
	if result.has("error"): return result
	result["phase"] = scaled % PERIOD
	result["counter_ticks"] = ticks
	return result
