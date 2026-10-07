extends RefCounted
## Normal-form controller8A364 six-slot aggregation. Inputs are signed bytes40/41/46.
static func aggregate(slots: Variant) -> Dictionary:
	if not slots is Array or slots.size()!=6: return {"error":"Expected six equipment slots."}
	var state := {"stat3a4":0,"stat3a8":0,"stat3ac":0,"stat3b0":0,"stat411":0,"stat40d":0}
	for index in range(6):
		var item: Variant = slots[index]
		if item==null: continue
		if not item is Array or item.size()!=3: return {"error":"Invalid equipment stat record."}
		for value in item:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)) or value < -128 or value > 127: return {"error":"Invalid signed equipment stat."}
		if index==2: state.stat3ac=int(item[0]);state.stat411=int(item[2])
		elif index==3: state.stat3b0=int(item[0]);state.stat40d=int(item[2])
		else: state.stat3a4+=int(item[0])
		state.stat3a8+=int(item[1])
	return {"state":state}

@warning_ignore("integer_division")
static func for_form(context: Variant, slots: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid form stat context."}
	var numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
	for field in ["form","base_attack","base_defense"]:
		if not numbers._integer(context.get(field),255): return {"error":"Unsupported form/base stat."}
	for field in ["prior_attack","prior_defense","boosted"]:
		if not numbers._integer(context.get(field),0xffffffff): return {"error":"Invalid prior form state."}
	var checked := aggregate(slots)
	if checked.has("error"): return checked
	var state := {"stat3a4":0,"stat3a8":0,"stat3ac":0,"stat3b0":0,"stat411":0,"stat40d":0,"attack":int(context.prior_attack),"defense":int(context.prior_defense),"signed_bonus":0}
	var form := int(context.form);var attack := int(context.base_attack);var defense := int(context.base_defense)
	if form in [1,8,9]:
		state.merge(checked.state,true);state.attack=attack;state.defense=defense
		if slots[2]==null: state.signed_bonus=-(attack/3)
	elif form in [2,4,5,7]: state.attack=attack;state.defense=defense
	elif form==3:
		state.attack=mini(255,attack*(5 if int(context.boosted)!=0 else 3))
		state.defense=mini(255,defense*(6 if int(context.boosted)!=0 else 4))
	elif form in [6,10,11]: state.attack=attack/2;state.defense=defense*2
	return {"state":state}

static func from_reward_checkpoint(saved: Variant, context: Variant, slots: Variant) -> Dictionary:
	var reward := preload("res://scripts/lol2/hive_reward_application.gd").restore(saved)
	if reward.has("error"): return reward
	if not context is Dictionary: return {"error":"Invalid reward controller context."}
	var supplied: Dictionary = context.duplicate(true)
	# D8B35 copies player151/155 to236D4/236D8 = controller23348+38C/+390.
	supplied.base_attack=reward.checkpoint.player.stat151
	supplied.base_defense=reward.checkpoint.player.stat155
	return for_form(supplied,slots)
