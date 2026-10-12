extends RefCounted
## Source frame cues; one saved voice per actor. Cadence/mixing are adapters.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
static func initial(actors: Array) -> Dictionary:
	var result: Dictionary={}
	for row in actors: result[str(int(row.actor))]={"selector":-1,"time":0.0,"request":0,"sample":0}
	return result
static func validate(packet: Variant, actors: Array, contract: Dictionary) -> String:
	if not packet is Dictionary or packet.size()!=actors.size(): return "Invalid creature audio identities."
	for row in actors:
		var v=packet.get(str(int(row.actor)))
		if not v is Dictionary: return "Missing creature audio voice."
		var selector=v.get("selector")
		if not (selector is int or selector is float) or not is_finite(float(selector)) or selector!=int(selector) or (selector!=-1 and not contract.definitions[str(int(row.definition))].has(str(int(selector)))): return "Invalid creature audio selector."
		if not Values.integer(v.get("request"),65535): return "Invalid creature audio request."
		var time=v.get("time")
		if not (time is int or time is float) or not is_finite(float(time)) or time<0 or time>1e9: return "Invalid creature audio clock."
		var request:=str(int(v.request))
		if v.request==0:
			if not Values.integer(v.get("sample"),0): return "Silent creature audio has a sample offset."
		elif not contract.samples.has(request) or not Values.integer(v.get("sample"),int(contract.samples[request])): return "Invalid creature audio sample offset."
	return ""
static func canonical(packet: Dictionary) -> Dictionary:
	var result:=packet.duplicate(true)
	for v in result.values():
		v.selector=int(v.selector);v.request=int(v.request);v.sample=int(v.sample);v.time=float(v.time)
	return result
static func advance(v: Dictionary, selector: int, time: float, delta: float, cues: Array, loop: float, fps: float, contract: Dictionary) -> void:
	if not is_finite(delta) or delta<0 or not is_finite(time) or time<0: return
	if int(v.request)!=0: v.sample=mini(int(contract.samples[str(int(v.request))]),int(v.sample)+roundi(delta*int(contract.rate)))
	time=snappedf(time,1.0/1024)
	var previous: float=float(v.time) if int(v.selector)==selector and time>=float(v.time) else -1.0
	var latest:=-1.0
	var request:=0
	for cue in cues:
		var occurrence:=float(cue[0])/fps
		if loop>0 and time>=occurrence: occurrence+=floor((time-occurrence)/loop)*loop
		if occurrence>previous and occurrence<=time and occurrence>latest:
			latest=occurrence;request=int(cue[1])
	if request!=0:
		v.request=request;v.sample=mini(roundi((time-latest)*int(contract.rate)),int(contract.samples[str(request)]))
	v.selector=selector;v.time=time
