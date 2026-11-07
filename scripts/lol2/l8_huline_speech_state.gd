extends RefCounted
const KEY:="l8_huline_speech"
const CUES:={"93":237,"92":1012,"23":1016,"82":1016}
const SAMPLES:={237:37632,1012:31296,1016:53696}
static func duration(id:String)->float:return float(SAMPLES[CUES[id]])/22050.0
static func initial()->Dictionary:return {"version":1,"heard":[],"active":"","elapsed":0.0}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("heard") is Array or not s.get("active") is String:return "Invalid Huline speech state."
 if not (s.get("elapsed") is float or s.get("elapsed") is int) or not is_finite(float(s.elapsed)) or s.elapsed<0:return "Invalid Huline speech clock."
 var seen:Array=[]
 for id in s.heard:
  if not id is String or not CUES.has(id) or id in seen:return "Invalid heard Huline speech."
  seen.append(id)
 if s.active=="":return "" if s.elapsed==0 else "Idle Huline speech clock changed."
 if not CUES.has(s.active) or s.active in seen or s.elapsed>duration(s.active):return "Invalid active Huline speech."
 return ""
