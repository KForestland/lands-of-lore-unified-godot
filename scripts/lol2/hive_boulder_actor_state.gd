extends RefCounted
## Actor scheduling adapter; source clips/path progression are independently checked.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Core=preload("res://scripts/lol2/hive_attack_runtime.gd")
const CONTRACT={"version":1,"clips":[{"selector":0,"frames":1,"interval":1024,"events":[]},{"selector":1,"frames":10,"interval":903,"events":[]}]}
const SPAWNS={"30":[-2194.0,-1207.0,-6549.0],"31":[-2270.0,-1207.0,-6889.0]}
static func initial(retired: bool=false) -> Dictionary:
	var actors: Dictionary={}
	for id in SPAWNS:
		actors[id]={"active":false,"stopping":false,"rolling":false,"position":SPAWNS[id].duplicate(),"velocity_y":0.0,"index":0,"frame":0,"timer":0,"fraction":0.0}
	return {"version":1,"legacy_retired":retired,"actors":actors}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not Values.integer(value.get("version"),1) or value.version!=1 or not value.get("legacy_retired") is bool or not value.get("actors") is Dictionary: return "Invalid boulder actors."
	if value.actors.size()!=2: return "Incomplete boulder actors."
	for id in SPAWNS:
		if not value.actors.get(id) is Dictionary: return "Missing boulder actor."
		var actor: Dictionary=value.actors[id]
		for key in ["active","stopping","rolling"]:
			if not actor.get(key) is bool: return "Invalid boulder actor flag."
		if not Values.vector(actor.get("position"),32768): return "Invalid boulder position."
		var velocity=actor.get("velocity_y")
		if not (velocity is int or velocity is float) or not is_finite(float(velocity)) or absf(float(velocity))>4096: return "Invalid boulder vertical speed."
		var index=actor.get("index")
		if not (index is int or index is float) or not is_finite(float(index)) or float(index)!=floorf(float(index)) or index < -11 or index>12: return "Invalid boulder path index."
		if not Values.integer(actor.get("frame"),9) or not Values.integer(actor.get("timer"),902): return "Invalid boulder animation clock."
		var f=actor.get("fraction")
		if not (f is int or f is float) or not is_finite(float(f)) or f<0 or f>=1: return "Invalid boulder sub-tick."
		if not actor.active and (actor.rolling or actor.stopping or actor.index!=0 or actor.velocity_y!=0 or actor.position!=SPAWNS[id]): return "Dormant boulder changed."
		if actor.stopping and not actor.active: return "Inactive boulder stop request."
		if not actor.rolling and (actor.frame!=0 or actor.timer!=0 or actor.fraction!=0): return "Idle boulder retains rolling clock."
		if actor.active and not actor.rolling and not actor.stopping: return "Activated boulder lost its stop state."
		if value.legacy_retired and actor.active: return "Retired legacy boulder activated."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	var result:=initial(value.legacy_retired)
	for id in SPAWNS:
		var actor: Dictionary=value.actors[id].duplicate(true)
		for key in ["index","frame","timer"]: actor[key]=int(actor[key])
		for key in ["velocity_y","fraction"]: actor[key]=float(actor[key])
		actor.position=[float(actor.position[0]),float(actor.position[1]),float(actor.position[2])]
		result.actors[id]=actor
	return result
static func apply_group(value: Dictionary, group: int) -> void:
	if value.legacy_retired: return
	for actor in value.actors.values():
		if group==6250 and not actor.active:
			actor.active=true
			actor.rolling=true
		elif group==6806 and actor.active: actor.stopping=true
static func advance_animation(actor: Dictionary, delta: float) -> bool:
	if not actor.rolling or not is_finite(delta) or delta<=0: return false
	# 15360 units/s is the existing presentation clock adapter, not native speed.
	var units: float=actor.fraction+delta*15360.0
	var ticks:=int(floorf(units))
	actor.fraction=units-floorf(units)
	var core=Core.new(CONTRACT)
	var saved: Dictionary=core.checkpoint()
	saved.merge({"selector":1,"frame":int(actor.frame),"timer":int(actor.timer)},true)
	var error: String=core.restore(saved)
	assert(error.is_empty())
	while ticks>0:
		var chunk:=mini(ticks,32767)
		# Consume the stop once, at the first terminal. Queue ordering is an adapter.
		if actor.stopping:
			var remaining:=int(actor.timer)+(8-int(actor.frame))*903+1 if actor.frame<9 else int(actor.timer)+903*9+1
			chunk=mini(chunk,remaining)
		var result: Dictionary=core.advance_native(chunk)
		ticks-=chunk
		for event in result.events:
			if event.type=="terminal" and actor.stopping:
				actor.rolling=false
				actor.frame=0
				actor.timer=0
				actor.fraction=0.0
				return true
		actor.frame=int(result.state.frame)
		actor.timer=int(result.state.timer)
	return false
