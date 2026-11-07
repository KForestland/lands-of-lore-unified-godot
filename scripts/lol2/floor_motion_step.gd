extends RefCounted
## Native6507B fixed-point quota/carry +65120 accepted-motion clamp +65194 height.
## Caller owns command start, B861C collision admission, completion events and cache/body updates.
## Positive speed only; source speed0 instant moves require a separate caller path.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
static func valid(s: Variant) -> bool:
	if not s is Dictionary:return false
	for key in ["height","remaining"]:
		var v=s.get(key)
		if not (v is int or v is float) or not is_finite(float(v)) or float(v)!=floorf(float(v)) or v < -32768 or v > 32767:return false
	return Values.integer(s.get("fraction"),65535) and Values.integer(s.get("speed"),255) and s.speed>0 and s.height+s.remaining>=-32768 and s.height+s.remaining<=32767
static func advance_one(s: Dictionary, tick_fixed: int) -> bool:
	if not valid(s) or tick_fixed<0 or tick_fixed>131072 or int(s.remaining)==0:return false
	var speed: int=int(s.speed)*10/4
	var quota: int=speed*tick_fixed/60
	var accumulated: int=int(s.fraction)+quota
	var distance: int=accumulated>>16
	s.fraction=accumulated&65535
	var movement:=mini(absi(int(s.remaining)),distance)*signi(int(s.remaining))
	s.height=int(s.height)+movement;s.remaining=int(s.remaining)-movement
	return s.remaining==0
