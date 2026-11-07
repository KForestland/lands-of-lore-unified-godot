extends RefCounted
## One saved voice per actor; PCM clocks and interruption policy are adapters.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const SAMPLES={351:13184,353:19584,354:17472,651:8928,978:17022,979:5822}
const CUES={1:[[0.0,351],[0.875,354]],2:[[0.0,351],[0.875,353]],4:[[1.0,978]],6:[[0.125,979]],7:[[0.125,979]],8:[[0.0,651],[0.875,354]]}
static func initial() -> Dictionary:
	var result: Dictionary={}
	for id in range(21,36): result[str(id)]={"pose":0,"time":0.0,"request":0,"elapsed":0}
	return result
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=15: return "Invalid DINO audio identities."
	for id in initial():
		var v=packet.get(id)
		if not v is Dictionary or not Values.integer(v.get("pose"),10) or not Values.integer(v.get("request"),979): return "Invalid DINO audio selection."
		for key in ["time","elapsed"]:
			if not (v.get(key) is int or v.get(key) is float) or not is_finite(float(v[key])) or v[key]<0 or v[key]>1e9: return "Invalid DINO audio clock."
		if v.request==0:
			if v.elapsed!=0: return "Idle DINO audio has a clock."
		elif not SAMPLES.has(int(v.request)) or not Values.integer(v.elapsed,SAMPLES[int(v.request)]): return "DINO audio exceeds clip."
	return ""
static func sample(v: Dictionary, pose: int, time: float, delta: float) -> void:
	if not is_finite(time) or time<0 or not is_finite(delta) or delta<0: return
	if int(v.request)!=0: v.elapsed=mini(int(SAMPLES[int(v.request)]),int(v.elapsed)+roundi(delta*22050.0))
	time=snappedf(time,1.0/1024)
	var previous: float=float(v.time) if int(v.pose)==pose and time>=float(v.time) else -1.0
	var latest:=-1.0
	var request:=0
	for cue in CUES.get(pose,[]):
		var occurrence:=float(cue[0])
		if pose in [1,2] and time>=occurrence: occurrence+=floor((time-occurrence)/1.75)*1.75
		if occurrence>previous and occurrence<=time and occurrence>latest:
			latest=occurrence;request=int(cue[1])
	if request!=0:
		v.request=request;v.elapsed=mini(roundi((time-latest)*22050.0),int(SAMPLES[request]))
	v.pose=pose;v.time=time
