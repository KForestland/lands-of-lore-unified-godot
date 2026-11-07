extends RefCounted
## Source floor targets; modern water clock/presentation, shared drowning limit.
const Breath=preload("res://scripts/lol2/river_drowning_state.gd")
const SPEED:=2.0 # 6507B integer (source speed1 * 10) / 4; continuous modern clock.
const LIMIT:=140.0 # Modern escape clock; later source-sector water caps at400.
static func initial()->Dictionary:return {"version":1,"elapsed":0.0,"breath":0.0,"dead":false}
static func validate(s: Variant)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("dead") is bool:return "Invalid ruins flood state."
 for key in ["elapsed","breath"]:
  var n=s.get(key)
  if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>(LIMIT if key=="elapsed" else Breath.LIMIT):return "Invalid ruins water clock."
 if s.dead!=(s.breath==Breath.LIMIT):return "Invalid ruins drowning receipt."
 return ""
static func height(row: Dictionary,elapsed: float)->float:
 if row.get("later",false):
  return move_toward(-2.0,70.0,2.0*maxf(0,elapsed-30)) if elapsed<=66 else move_toward(70.0,400.0,10.0*(elapsed-66))
 return move_toward(float(row.floor[0]),float(row.target),SPEED*elapsed)
static func advance(s: Dictionary,delta: float,submerged: bool)->void:
 if not is_finite(delta) or delta<=0 or s.dead:return
 s.elapsed=minf(LIMIT,float(s.elapsed)+delta)
 s.breath=minf(Breath.LIMIT,float(s.breath)+delta) if submerged else 0.0
 s.dead=s.breath>=Breath.LIMIT
