extends RefCounted
## Native AAD8E scan; caller supplies the scorer's ordered positive candidates.
const Admission=preload("res://scripts/lol2/dawn_spell_admission.gd")
const Validation=preload("res://scripts/lol2/hive_player_conditions.gd")
const CANDIDATES=[7,32,39,40,50,58]
static func scan(context: Variant, scores: Variant, maximum: Variant, window: Variant, previous: Variant, rng: Variant, supplied_candidates: Variant=CANDIDATES) -> Dictionary:
	if not context is Dictionary or not scores is Dictionary: return {"error":"Invalid selection context."}
	if not supplied_candidates is Array or supplied_candidates.is_empty() or supplied_candidates.size()>6: return {"error":"Invalid Dawn candidates."}
	var candidates: Array=[]
	for value in supplied_candidates:
		if not Validation._integer(value,0,112) or int(value) not in CANDIDATES or (not candidates.is_empty() and int(value)<=int(candidates[-1])): return {"error":"Invalid Dawn candidate order."}
		candidates.append(int(value))
	for value in [maximum,window]:
		if not Validation._integer(value,0,0x3fffffff): return {"error":"Invalid score window."}
	if not Validation._integer(previous,0,255) or not Validation._integer(rng,0,candidates.size()*32-1): return {"error":"Invalid previous spell/RNG."}
	for spell in candidates:
		if not Validation._integer(scores.get(str(spell)),-0x3fffffff,0x3fffffff): return {"error":"Invalid candidate score."}
	var owner: Dictionary=context.duplicate(true)
	owner.spell=7
	var checked:=Admission.admit(owner)
	if checked.has("error"): return checked
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
