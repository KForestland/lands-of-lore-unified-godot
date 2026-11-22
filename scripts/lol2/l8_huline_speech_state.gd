extends RefCounted
const KEY:="l8_huline_speech"
const CUES:={"93":237,"92":1012,"23":1016,"82":1016}
## Withheld cues are never started (lead 2026-11-17): the owner heard cue 93 (selector 237) on the good path as an evil-Luther
## line ('I took it from your mother's corpse', r19p F10 14-48-12), so its selector -> clip binding is unverified. Saves that
## already hold it stay valid; a save caught mid-line on it ends the line at once.
const WITHHELD:=["93"]
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
