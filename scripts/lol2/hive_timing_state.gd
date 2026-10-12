extends RefCounted
## Godot area timing checkpoint, not a decoder for native DOS saves.
## The controller clock is shared; actor36 owns executioner_a3.
const Clock = preload("res://scripts/lol2/hive_clock_runtime.gd")
const VERSION := 1

static func checkpoint(clock: Variant, phase: Variant, executioner_a3: Variant) -> Dictionary:
	if not Clock._integer(executioner_a3,255): return {"error":"Invalid executioner A3."}
	# Validate without sampling, consuming elapsed time or changing provider phase.
	var checked := Clock.advance_reference_time(clock,0,phase,false)
	if checked.has("error"): return checked
	var normalized := Clock.initial_state()
	for i in range(4): normalized.samples[i] = int(clock.samples[i])
	for field in ["cursor","fraction8","fraction16","status_accum","seconds"]:
		normalized[field] = int(clock[field])
	return {"checkpoint":{"version":VERSION,"clock":normalized,"phase":int(phase),"executioner_a3":int(executioner_a3)}}

static func restore(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Clock._integer(saved.get("version"),VERSION) or saved.version != VERSION:
		return {"error":"Unsupported Hive timing checkpoint."}
	return checkpoint(saved.get("clock"),saved.get("phase"),saved.get("executioner_a3"))
