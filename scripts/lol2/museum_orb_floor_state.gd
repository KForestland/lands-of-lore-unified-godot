extends RefCounted
## Source speed15 -> integer37, whole-unit heights and16.16 distance carry.
## A60Hz host adapter supplies native tick65536; original wall-clock producer untraced.
## Timer retains the independently verified one-expiry-per-host-update carry rule.
const Motion=preload("res://scripts/lol2/floor_motion_step.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const LOW := -50.0
const HIGH := 30.0
const PERIOD := 600.0
static func initial() -> Dictionary:
	return {"version":3,"local20":false,"height":int(LOW),"target":LOW,"timer":PERIOD,"motion_fraction":0,"motion_ticks":0.0}
static func validate(v: Variant) -> String:
	if v==null:return ""
	if not v is Dictionary:return "Invalid orb floor."
	if v.get("version")==1:return "" if v.size()==2 and v.get("raised") is bool else "Invalid legacy orb floor."
	if (v.get("version")!=2 and v.get("version")!=3) or v.size()!=(5 if v.version==2 else 7) or not v.get("local20") is bool:return "Invalid orb floor."
	for key in ["height","target","timer"]:
		var n=v.get(key)
		if not (n is int or n is float) or not is_finite(float(n)):return "Invalid orb floor number."
	if v.height<LOW or v.height>HIGH or v.timer<0 or v.timer>PERIOD:return "Invalid orb floor range."
	if v.target!=(HIGH if v.local20 else LOW):return "Orb floor target disagrees with local20."
	if v.version==3:
		if float(v.height)!=floorf(float(v.height)) or not Values.integer(v.get("motion_fraction"),65535):return "Invalid orb floor motion carry."
		var ticks=v.get("motion_ticks")
		if not (ticks is int or ticks is float) or not is_finite(float(ticks)) or ticks<0 or ticks>=1:return "Invalid orb floor tick carry."
	return ""
static func restore(v: Variant) -> Dictionary:
	if v==null:return initial()
	var s:=initial()
	if v.version==1:
		if v.raised:s.local20=true;s.height=int(HIGH);s.target=HIGH
		return s
	s.local20=bool(v.local20);s.target=float(v.target);s.timer=float(v.timer)
	if v.version==3:
		s.height=int(v.height);s.motion_fraction=int(v.motion_fraction);s.motion_ticks=float(v.motion_ticks)
	else:
		# Unreleased v2 stored fractional heights. Preserve travel progress in the
		# new carry, quantising collision height by less than one native unit.
		s.height=int(floorf(v.height) if v.target>v.height else ceilf(v.height))
		s.motion_fraction=clampi(int(round(absf(float(v.height)-s.height)*65536)),0,65535)
	return s
static func use(s: Dictionary) -> bool:
	if s.local20:return false
	s.local20=true;s.target=HIGH;s.timer=PERIOD;s.motion_fraction=0;s.motion_ticks=0.0
	return true
static func advance(s: Dictionary, delta: float) -> bool:
	if not is_finite(delta) or delta<=0:return false
	var old_height: int=s.height
	s.motion_ticks+=delta*60.0
	while s.motion_ticks>=1.0:
		s.motion_ticks-=1.0
		if s.height==int(s.target):continue
		var motion: Dictionary={"height":s.height,"remaining":int(s.target)-int(s.height),"fraction":s.motion_fraction,"speed":15}
		Motion.advance_one(motion,65536)
		s.height=motion.height;s.motion_fraction=motion.fraction
	var step:=delta*60.0
	var expired: bool=float(s.timer)<=step
	if expired:
		s.timer=float(s.timer)+PERIOD-step if PERIOD>step else 0.0
		if s.local20:s.local20=false;s.target=LOW;s.motion_fraction=0;s.motion_ticks=0.0
	else:s.timer=float(s.timer)-step
	return s.height!=old_height or expired
