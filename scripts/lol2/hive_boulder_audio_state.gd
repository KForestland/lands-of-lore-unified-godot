extends RefCounted
## Saved host PCM clocks; native sound-manager/save scheduling remains separate.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Surface=preload("res://scripts/lol2/hive_boulder_sequence.gd")
const LENGTHS={"close":32256.0/22050.0,"exit":47616.0/22050.0,"30":7616.0/22050.0,"31":7616.0/22050.0}
static func initial() -> Dictionary:
	return {"version":1,"clocks":{"close":-1.0,"exit":-1.0,"30":-1.0,"31":-1.0}}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not Values.integer(value.get("version"),1) or value.version!=1 or not value.get("clocks") is Dictionary or value.clocks.size()!=4: return "Invalid boulder audio packet."
	for key in LENGTHS:
		var clock=value.clocks.get(key)
		if not (clock is int or clock is float) or not is_finite(float(clock)): return "Invalid boulder audio clock."
		if clock!=-1 and (clock<0 or clock>LENGTHS[key] or (key in ["30","31"] and clock==LENGTHS[key])): return "Boulder audio clock outside clip."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	var result:=initial()
	for key in LENGTHS: result.clocks[key]=float(value.clocks[key])
	return result
static func validate_context(value: Dictionary,surfaces: Dictionary,actors: Dictionary) -> String:
	var error:=validate(value)
	if not error.is_empty(): return error
	if (value.clocks.close>=0)!=(surfaces.phase>=1) or (value.clocks.exit>=0)!=(surfaces.phase==3): return "Boulder audio disagrees with surfaces."
	for id in ["30","31"]:
		if (value.clocks[id]>=0)!=(not actors.legacy_retired and actors.actors[id].rolling): return "Boulder sound disagrees with owner."
	return ""
static func legacy(surfaces: Dictionary,actors: Dictionary) -> Dictionary:
	var value:=initial()
	# Older saves have no one-shot history. Do not replay an old surface cue.
	if surfaces.phase>=1: value.clocks.close=LENGTHS.close
	if surfaces.phase==3: value.clocks.exit=LENGTHS.exit
	for id in ["30","31"]:
		if not actors.legacy_retired and actors.actors[id].rolling: value.clocks[id]=0.0
	return value
static func active(value: Dictionary,key: String) -> bool:
	return value.clocks[key]>=0 and (key in ["30","31"] or value.clocks[key]<LENGTHS[key])
static func advance(value: Dictionary,before: Dictionary,after: Dictionary,actors: Dictionary,delta: float) -> bool:
	if not validate(value).is_empty() or not is_finite(delta) or delta<0: return false
	var to_roll:=0.0
	if before.phase==0: to_roll=Surface.CLOSE_SECONDS
	elif before.phase==1: to_roll=Surface.CLOSE_SECONDS-float(before.elapsed)
	var to_exit:=to_roll
	if before.phase<2: to_exit+=Surface.LOWER_SECONDS
	elif before.phase==2: to_exit=Surface.LOWER_SECONDS-float(before.elapsed)
	for key in ["close","exit"]:
		if value.clocks[key]>=0:
			value.clocks[key]=minf(LENGTHS[key],float(value.clocks[key])+delta)
		elif (key=="close" and after.phase>=1) or (key=="exit" and after.phase==3):
			value.clocks[key]=minf(LENGTHS[key],maxf(0.0,delta-(to_exit if key=="exit" else 0.0)))
	for id in ["30","31"]:
		if actors.legacy_retired or not actors.actors[id].rolling: value.clocks[id]=-1.0
		elif value.clocks[id]<0: value.clocks[id]=fposmod(maxf(0.0,delta-to_roll),LENGTHS[id])
		else: value.clocks[id]=fposmod(float(value.clocks[id])+delta,LENGTHS[id])
	return true
static func spatial_factor(native_delta: Vector3,near_distance: int,far_distance: int) -> int:
	# Native E4FCE uses signed 16.16 subtraction then arithmetic shift.
	var components: Array[int]=[absi(floori(native_delta.x)),absi(floori(native_delta.y)),absi(floori(native_delta.z))]
	components.sort()
	var distance: int=components[2]+((components[0]+components[1])>>2)
	if distance>far_distance: return 0
	if distance<=near_distance: return 255
	return maxi(1,((far_distance-distance)<<8)/(far_distance-near_distance))
static func drift(key: String,playback: float,clock: float) -> float:
	var difference:=absf(playback-clock)
	if key in ["30","31"]:
		difference=absf(fposmod(playback,LENGTHS[key])-clock)
		difference=minf(difference,LENGTHS[key]-difference)
	return difference
