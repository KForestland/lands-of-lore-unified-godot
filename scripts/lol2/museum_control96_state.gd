extends RefCounted
## Source groups7684/7730/7788; endpoint timing is a documented playback adapter.
const FPS := 15.0
static func initial() -> Dictionary:
	return {"version":1,"latched":false,"stage":-1,"elapsed":0.0,"state":0,"present":true,"control179":false,"spawned30":false}
static func duration(stage: int) -> float: return 27.0/FPS if stage==0 else 41.0/FPS
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size()!=8: return "Invalid control96 packet."
	for key in ["version","stage","state"]:
		var n=value.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n!=int(n): return "Invalid control96 integer."
	if value.version!=1 or value.stage < -1 or value.stage>2 or int(value.state) not in [0,1]: return "Invalid control96 stage."
	for key in ["latched","present","control179","spawned30"]:
		if not value.get(key) is bool: return "Invalid control96 flag."
	var elapsed=value.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed<0: return "Invalid control96 clock."
	if value.latched!=(value.stage>=0) or value.present!=(value.stage<2) or value.spawned30!=(value.stage==2) or value.control179!=(value.stage>=1) or value.state!=int(value.stage>=1): return "Inconsistent control96 sequence."
	if int(value.stage) in [-1,2] and elapsed!=0: return "Inconsistent control96 clock."
	if int(value.stage) in [0,1] and elapsed>=duration(int(value.stage)): return "Invalid control96 endpoint."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	var r=value.duplicate(true)
	for key in ["version","stage","state"]: r[key]=int(r[key])
	r.elapsed=float(r.elapsed)
	return r
static func admit(state: Dictionary) -> bool:
	if state.latched or not state.present: return false
	state.latched=true;state.stage=0;state.elapsed=0.0
	return true
static func advance(state: Dictionary, delta: float) -> Array:
	var effects: Array=[]
	if not is_finite(delta) or delta<=0: return effects
	while state.stage in [0,1]:
		var remaining: float=duration(int(state.stage))-float(state.elapsed)
		if delta<remaining: state.elapsed+=delta;break
		delta-=remaining;state.elapsed=0.0
		if state.stage==0:
			# Event0 predicate19 evaluates before group7730 changes state0->1.
			state.stage=1;state.state=1;state.control179=true
			effects.append("activate179")
		else:
			# Second event0 queues unconditional7730 then predicate19 group7788.
			state.stage=2;state.present=false;state.spawned30=true
			effects.append("spawn30")
	return effects
static func frame(state: Dictionary) -> int:
	if state.stage<0: return -1
	if state.stage==2: return 67
	return (0 if state.stage==0 else 27)+int(float(state.elapsed)*FPS)
