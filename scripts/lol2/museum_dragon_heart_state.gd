extends RefCounted
## Original prop216: kind9/group4536 starts once; completion group4564 reveals item25/local8=2.
## Region365/769 then unload prop216 and link spent prop215. Modern elapsed checkpoint.
const ITEM := "museum:item25:Dragon_Gem"
const DURATION := 20.0/15.0
static func initial() -> Dictionary:
	return {"version":1,"phase":"idle","elapsed":0.0,"taken":false}
static func validate(value: Variant, carried: Array) -> String:
	if value==null:
		return "Dragon Gem lacks an earned receipt." if ITEM in carried else ""
	if not value is Dictionary or value.size()!=4 or value.get("version")!=1 or not value.get("phase") in ["idle","playing","revealed","departed"] or not value.get("taken") is bool:return "Invalid dragon-heart checkpoint."
	var elapsed=value.get("elapsed")
	if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>DURATION:return "Invalid dragon-heart time."
	if value.phase=="idle" and elapsed!=0:return "Idle dragon heart has movie time."
	if value.phase=="playing" and elapsed>=DURATION:return "Completed dragon heart still playing."
	if value.phase in ["revealed","departed"] and elapsed!=DURATION:return "Dragon-heart reward lacks movie completion."
	if value.taken and not value.phase in ["revealed","departed"]:return "Unearned Dragon Gem."
	if value.taken!=(ITEM in carried):return "Dragon Gem and inventory disagree."
	return ""
static func spark(state: Dictionary) -> bool:
	if state.phase!="idle":return false
	state.phase="playing";state.elapsed=0.0
	return true # Host applies original op2/sub10/arg5:50magic experience exactly once here.
static func advance(state: Dictionary, delta: float) -> bool:
	if state.phase!="playing" or not is_finite(delta) or delta<=0:return false
	state.elapsed=minf(DURATION,float(state.elapsed)+delta)
	if state.elapsed==DURATION:
		state.phase="revealed";return true
	return false
static func region_enter(state: Dictionary, region: int) -> void:
	if state.phase=="revealed" and region in [365,769]:state.phase="departed"
