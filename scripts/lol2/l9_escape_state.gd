extends RefCounted
## Lead-authorized modern lift and raft motion; source placements/exit are retained.
const KEY:="l9_escape"
const DURATION:=16.0
static func initial()->Dictionary:return {"version":1,"boarded":false,"lift":0.0,"raft":0.0,"escaped":false}
static func validate(s: Variant)->String:
 if not s is Dictionary or s.size()!=5 or s.get("version")!=1 or not s.get("boarded") is bool or not s.get("escaped") is bool:return "Invalid ruins escape state."
 for key in ["lift","raft"]:
  var n=s.get(key)
  if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>(DURATION if key=="lift" else 5.0):return "Invalid ruins escape clock."
 if not s.boarded and s.lift!=0:return "Unboarded lift moved."
 if s.raft>0 and s.lift!=DURATION:return "Raft reached before the lift completed."
 if s.escaped!=(s.raft==5.0):return "Invalid raft completion."
 return ""
