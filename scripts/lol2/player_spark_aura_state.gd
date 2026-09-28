extends RefCounted
## Effect24 source timer is16.16;60 source ticks/sec and1s pulses are adapters.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const EXTEND := 600 << 16
const TICKS_PER_SECOND := 60.0
const PULSE_SECONDS := 1.0
static func initial() -> Dictionary:
	return {"timer":0,"fraction":0.0,"pulse":0.0,"seed":324508639,"area":"","bolts":[]}
static func validate(s: Variant) -> String:
	if not s is Dictionary: return "Invalid Spark aura."
	for key in ["timer","seed"]:
		if not Values.integer(s.get(key),0xffffffff): return "Invalid Spark aura counter."
	for key in ["fraction","pulse"]:
		var n = s.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n < 0 or n >= 1: return "Invalid Spark aura clock."
	if not s.get("area") is String or s.area not in ["","res://scenes/lol2/cave_walkthrough.tscn","res://scenes/lol2/museum_walkthrough.tscn","res://scenes/lol2/jungle_walkthrough.tscn","res://scenes/lol2/hive_review.tscn"]: return "Invalid Spark aura area."
	if not s.get("bolts") is Array or s.bolts.size() > 128: return "Invalid Spark aura bolts."
	if not s.bolts.is_empty() and s.area.is_empty(): return "Spark bolts require an area."
	for bolt in s.bolts:
		if not bolt is Dictionary or bolt.get("target") not in ["roach23","guardian32","guardian34","executioner36","hivewarrior23","hivewarrior24","hivewarrior25","hivewarrior26","hivewarrior27","hivewarrior28","hivewarrior29"]: return "Invalid Spark target."
		if not Values.integer(bolt.get("effect"),23) or bolt.effect < 20: return "Invalid Spark effect."
		if not Values.vector(bolt.get("position"),32768): return "Invalid Spark bolt position."
		var life = bolt.get("life")
		if not (life is int or life is float) or not is_finite(float(life)) or life <= 0 or life > 5: return "Invalid Spark bolt lifetime."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var result := s.duplicate(true)
	for key in ["timer","seed"]: result[key] = int(result[key])
	for key in ["fraction","pulse"]: result[key] = float(result[key])
	for bolt in result.bolts:
		bolt.target = str(bolt.target)
		bolt.effect = int(bolt.effect)
		bolt.life = float(bolt.life)
		bolt.position = bolt.position.map(func(n): return float(n))
	return result
static func active(s: Dictionary) -> bool:
	return int(s.timer) != 0
static func extend(s: Dictionary) -> void:
	# Native adds600 to the high word without replacing the fractional low word.
	s.timer = (int(s.timer)+EXTEND)&0xffffffff
static func draw_effect(s: Dictionary) -> int:
	s.seed = (1664525*int(s.seed)+1013904223)&0xffffffff
	return 20+((int(s.seed)%128)>>5)
static func advance(s: Dictionary, seconds: float) -> Dictionary:
	if not is_finite(seconds) or seconds <= 0 or not active(s): return {"expired":false,"pulses":0}
	var before := int(s.timer)
	var active_seconds := minf(seconds,float(before)/65536.0/TICKS_PER_SECOND) if before <= 0x7fffffff else 0.0
	var fixed: float = seconds*TICKS_PER_SECOND*65536.0+float(s.fraction)
	var ticks := int(floorf(fixed))
	s.fraction = fixed-ticks
	var remaining := before-ticks
	var expired := before > 0x7fffffff or remaining <= 0
	s.timer = 0 if expired else remaining
	var pulse: float = float(s.pulse)+maxf(0.0,active_seconds-(0.000000001 if expired else 0.0))
	var count := int(floorf(pulse/PULSE_SECONDS))
	s.pulse = fmod(pulse,PULSE_SECONDS)
	if expired:
		s.fraction = 0.0
		s.pulse = 0.0
	return {"expired":expired,"pulses":count}
