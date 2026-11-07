extends RefCounted
## Source floor command parameters; modern entry trigger and fixed 60 Hz clock.
const KEY="l12_glacier"
const Motion=preload("res://scripts/lol2/floor_motion_step.gd")
static func initial()->Dictionary:return {"version":1,"started":false,"clock":0.0,"motion":{"height":-590,"remaining":0,"fraction":0,"speed":50}}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("started") is bool:return "Invalid Claw glacier state."
 if not Motion.valid(s.get("motion")) or s.motion.size()!=4 or s.motion.speed!=50:return "Invalid Claw glacier motion."
 var clock=s.get("clock")
 if not (clock is int or clock is float) or not is_finite(float(clock)) or clock<0 or clock>=1:return "Invalid Claw glacier clock."
 if not s.started:
  if s.motion.height!=-590 or s.motion.remaining!=0 or s.motion.fraction!=0 or clock!=0:return "Changed inactive glacier."
 elif s.motion.height< -1090 or s.motion.height> -590 or s.motion.height+s.motion.remaining!=-1090:return "Invalid glacier target."
 return ""
static func start(s:Dictionary)->bool:
 if s.started or not validate(s).is_empty():return false
 s.started=true;s.motion.remaining=-500;return true
static func advance(s:Dictionary,delta:float)->void:
 if not s.started or s.motion.remaining==0 or not is_finite(delta) or delta<=0:return
 s.clock=float(s.clock)+delta*60
 while s.clock>=1:
  s.clock-=1;Motion.advance_one(s.motion,65536)
