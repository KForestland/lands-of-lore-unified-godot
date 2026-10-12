extends RefCounted
## Original D0BEC reward branch after caller admission: request mode1/5 award
## fighting (D8A1C), mode2 awards magic (D8B94) from effect window byte1.
## Pure planner: which mode/effect a live spell writes is not bound here.
const Feedback = preload("res://scripts/lol2/hive_sword_feedback.gd")
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func plan(request: Variant, player: Variant, bases: Variant) -> Dictionary:
	if not request is Dictionary or not player is Dictionary: return {"error":"Invalid spell reward input."}
	if not bases is Array or bases.size() != 256: return {"error":"Invalid effect reward window."}
	for field in ["mode","effect"]:
		if not Numbers._integer(request.get(field),255): return {"error":"Invalid request field: "+field}
	if not Numbers._integer(request.get("scale"),255) or int(request.scale)<1: return {"error":"Invalid request scale."}
	for field in ["loss","remaining","special"]:
		if not Numbers._integer(request.get(field),0xffffffff): return {"error":"Invalid request field: "+field}
	for field in ["fighting_level","magic_level"]:
		if not Numbers._integer(player.get(field),255): return {"error":"Invalid player field: "+field}
	var mode := int(request.mode)
	var none := {"bank":"none","award":0,"marker":-1}
	if int(request.loss)==0 or mode not in [1,2,5]: return none
	var scale := int(request.scale)
	var base := 0
	var difference := 0
	var marker := 0
	if mode==2:
		var entry: Variant = bases[int(request.effect)]
		if not Numbers._integer(entry,255): return {"error":"Invalid effect reward entry."}
		var loss := int(request.loss)
		if loss >= 0x80000000: loss -= 0x100000000
		base = int(entry)*(3 if loss>1 else 1)
		difference = scale-int(player.magic_level)
		marker = 2
	else:
		base = scale*(10 if int(request.remaining)==0 else 3 if int(request.special)!=0 else 1)
		difference = scale-int(player.fighting_level)
	var award := 0
	if base > 0:
		var scaled := Feedback.scale_reward(base,difference)
		if scaled.has("error"): return scaled
		award = int(scaled.award)
	var bank := "none" if award==0 else ("magic" if mode==2 else "fighting")
	return {"bank":bank,"award":award,"marker":marker,"base":base,"difference":difference}
