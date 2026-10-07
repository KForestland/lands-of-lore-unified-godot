extends RefCounted
## Native AAD8E scan for Dawn's six candidates; caller owns score production/RNG.
const Admission=preload("res://scripts/lol2/dawn_spell_admission.gd")
const Validation=preload("res://scripts/lol2/hive_player_conditions.gd")
const CANDIDATES=[7,32,39,40,50,58]
static func scan(context: Variant, scores: Variant, maximum: Variant, window: Variant, previous: Variant, rng: Variant) -> Dictionary:
	if not context is Dictionary or not scores is Dictionary: return {"error":"Invalid selection context."}
	for value in [maximum,window]:
		if not Validation._integer(value,0,0x3fffffff): return {"error":"Invalid score window."}
	if not Validation._integer(previous,0,255) or not Validation._integer(rng,0,191): return {"error":"Invalid previous spell/RNG."}
	for spell in CANDIDATES:
		if not Validation._integer(scores.get(str(spell)),-0x3fffffff,0x3fffffff): return {"error":"Invalid candidate score."}
	var owner: Dictionary=context.duplicate(true)
	owner.spell=7
	var checked:=Admission.admit(owner)
	if checked.has("error"): return checked
	var candidates:=CANDIDATES.duplicate()
	var start:=candidates.find(int(previous))
	if start>=0 and (int(owner.b8)&128)!=0: start=(start+1)%candidates.size()
	owner.b8=int(owner.b8)&~128
	if start<0: start=int(rng)>>5
	var chosen:=start
	var attempts: Array=[]
	var accepted:=false
	var threshold:=int(maximum)-int(window)
	for step in range(candidates.size()):
		var index: int=(start+step)%candidates.size()
		var spell:=int(candidates[index])
		if int(scores[str(spell)])<threshold:
			candidates[index]=0
			continue
		owner.spell=spell;owner.check_cost=1;owner.write_reason=1
		var result:=Admission.admit(owner)
		owner.b8=result.b8;owner.previous_reason=result.stored_reason
		attempts.append({"spell":spell,"admitted":result.accepted,"reason":result.reason})
		if result.accepted:
			chosen=index;accepted=true
			break
	# Native can store a nonzero choice when all admissions fail. This is not a cast.
	return {"stored_choice":candidates[chosen],"accepted":accepted,"attempts":attempts,"candidates":candidates,"b8":owner.b8}
