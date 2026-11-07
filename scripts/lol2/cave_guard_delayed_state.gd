extends RefCounted
## Original prop515 one-shot timer. Caller supplies game ticks and world pause gate.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
static func source() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_guard_external_source.json"))
static func initial() -> Dictionary:return {"left":120,"started":false,"fired":false,"audio":-1.0}
static func duration() -> float:
	var clip: Dictionary=source().audio["323"]
	return ceilf(float(clip.samples)/float(clip.rate)*4096.0)/4096.0
static func validate(s: Variant, sequence_complete: bool, fired_receipt: bool) -> String:
	if not s is Dictionary or not Values.integer(s.get("left"),120):return "Invalid guard timer counter."
	for key in ["started","fired"]:
		if not s.get(key) is bool:return "Invalid guard timer latch."
	if s.started!=sequence_complete or s.fired!=fired_receipt or (s.fired and not s.started):return "Guard timer producer mismatch."
	var t=s.get("audio")
	if not (t is int or t is float) or not is_finite(float(t)) or t<(-1 if not s.fired else 0) or t>duration():return "Invalid guard timer voice clock."
	if not s.fired and t!=-1:return "Guard timer voice has no producer."
	if not s.started and s.left!=120:return "Idle guard timer changed."
	if s.started and not s.fired and s.left==0:return "Running guard timer has expired without receipt."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true);r.left=int(r.left);r.audio=float(r.audio);return r
static func start(s: Dictionary) -> void:s.started=true
static func step(s: Dictionary, ticks: int) -> bool:
	if not s.started or s.fired or ticks<=0:return false
	var left:=int(s.left)
	if left>ticks:s.left=left-ticks;return false
	# Native reload/carry runs before source g5050 stops the one-shot timer.
	s.left=left+120-ticks if 120>ticks else 0;s.fired=true;s.audio=0.0
	return true
static func advance_audio(s: Dictionary, delta: float) -> void:
	if not s.fired or not is_finite(delta) or delta<=0:return
	s.audio=minf(duration(),snappedf(float(s.audio)+delta,1.0/4096))
