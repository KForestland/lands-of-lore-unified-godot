extends RefCounted
## Actor24 use→state1/event3→path1→event22→120tick removal.
## Path speed and one-frame event3 scheduling are explicit modern adapters.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const SPEED:=80.0
static func source() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_eyes_source.json"))
static func initial(src: Dictionary) -> Dictionary:
	return {"version":1,"phase":"idle","position":src.position.duplicate(),"index":0,"clock":0.0,"animation":0.0,"sound_sample":0.0}
static func validate(saved: Variant, src: Dictionary) -> String:
	if not saved is Dictionary or not Values.integer(saved.get("version"),1) or saved.version!=1: return "Invalid cave eyes version."
	if saved.get("phase") not in ["idle","starting","moving","retiring","removed"]: return "Invalid cave eyes phase."
	if not Values.vector(saved.get("position"),32768) or not Values.integer(saved.get("index"),src.path.points.size()-1): return "Invalid cave eyes path."
	for key in ["clock","animation","sound_sample"]:
		var value=saved.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value<0: return "Invalid cave eyes clock."
	if saved.animation>=23.0/15.0 or saved.clock>2.0 or saved.sound_sample>int(src.sound.samples): return "Invalid cave eyes clock range."
	if saved.phase=="idle" and (saved.position!=src.position or saved.index!=0 or saved.clock!=0 or saved.sound_sample!=0): return "Idle cave eyes changed."
	if saved.phase=="starting" and (saved.index!=0 or saved.clock>10.0/15.0): return "Invalid cave eyes start."
	if saved.phase in ["retiring","removed"] and saved.index!=src.path.points.size()-1: return "Invalid cave eyes terminal."
	return ""
static func canonical(saved: Dictionary) -> Dictionary:
	var result: Dictionary=saved.duplicate(true)
	result.version=1;result.index=int(result.index);result.clock=float(result.clock);result.animation=float(result.animation);result.sound_sample=float(result.sound_sample)
	result.position=[float(result.position[0]),float(result.position[1]),float(result.position[2])]
	return result
## Displayed frame, exactly as cave_eyes.gd presents it (moving loops 23 frames, the rest 10).
static func frame(animation: float, phase: String) -> int: return int(animation*15.0)%(23 if phase=="moving" else 10)
## Saved form. Godot's JSON parse does not read 17-significant-digit decimals back bit-exactly; short
## dyadic values do, so a disk checkpoint restores exactly what was saved. Clocks/animation (<2 s) use
## 1/4096 s, sound whole samples, positions 1/256 unit (all <=13 digits). Animation keeps its displayed
## frame and stays below its loop limit: floor to a step, else the next step up (a frame spans ~273
## steps), else 0.0 when float rounding already shows a value just under the limit as the wrapped
## frame 0. Clocks floor (never past a phase limit). Live advancement is not quantized.
static func quantized(saved: Dictionary) -> Dictionary:
	var result:=canonical(saved)
	result.clock=floorf(float(result.clock)*4096.0)/4096.0
	result.sound_sample=floorf(float(result.sound_sample))
	var live:=float(result.animation)
	var limit:=(23.0 if result.phase=="moving" else 10.0)/15.0
	var shown:=frame(live,result.phase)
	result.animation=0.0
	for candidate in [floorf(live*4096.0)/4096.0,ceilf(live*4096.0)/4096.0]:
		if candidate<limit and frame(candidate,result.phase)==shown: result.animation=candidate;break
	result.position=result.position.map(func(v): return snappedf(float(v),1.0/256))
	return result
static func use(saved: Dictionary) -> bool:
	if saved.phase!="idle": return false
	saved.phase="starting";saved.clock=fmod(float(saved.animation),10.0/15.0)
	return true
static func advance(saved: Dictionary, src: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0 or saved.phase=="removed": return
	if saved.phase=="idle":
		saved.animation=fmod(float(saved.animation)+delta,10.0/15.0)
		return
	saved.sound_sample=minf(float(src.sound.samples),float(saved.sound_sample)+delta*float(src.sound.rate))
	var remaining:=delta
	if saved.phase=="starting":
		var amount:=minf(remaining,10.0/15.0-float(saved.clock))
		saved.clock+=amount;saved.animation=float(saved.clock);remaining-=amount
		if saved.clock>=10.0/15.0-0.000001: saved.phase="moving";saved.clock=0.0;saved.animation=0.0
	while remaining>0 and saved.phase=="moving":
		var p:=Vector3(saved.position[0],saved.position[1],saved.position[2])
		var row: Array=src.path.points[int(saved.index)].position
		var target:=Vector3(row[0],p.y,row[2])
		var distance:=p.distance_to(target)
		var seconds:=minf(remaining,distance/SPEED)
		p=p.move_toward(target,seconds*SPEED);remaining-=seconds
		saved.animation=fmod(float(saved.animation)+seconds,23.0/15.0)
		saved.position=[p.x,p.y,p.z]
		if p.distance_to(target)<0.001:
			if int(saved.index)+1<src.path.points.size(): saved.index+=1
			else: saved.phase="retiring";saved.clock=0.0;saved.animation=0.0
		else: break
	if saved.phase=="retiring":
		saved.animation=fmod(float(saved.animation)+minf(remaining,2.0-float(saved.clock)),10.0/15.0)
		saved.clock=minf(2.0,float(saved.clock)+remaining)
		if saved.clock>=2.0: saved.phase="removed"
