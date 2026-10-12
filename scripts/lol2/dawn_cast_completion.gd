extends RefCounted
## Native A9517 dispatch tail. Spell32 reaches it even on allocation/constructor failure.
## The caller must bind dispatch arrival here; effect construction success is not the gate.
const Admission=preload("res://scripts/lol2/dawn_spell_admission.gd")
const Validation=preload("res://scripts/lol2/hive_player_conditions.gd")
@warning_ignore("integer_division")
static func complete(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid cast completion context."}
	for field in {"spell":255,"difficulty":2,"mana":65535,"bar":255,"flags":255}:
		var maximum: int=2 if field=="difficulty" else 65535 if field=="mana" else 255
		if not Validation._integer(context.get(field),0,maximum): return {"error":"Invalid cast completion field."}
	if not context.get("charge") is bool or not Admission.DESCRIPTORS.has(int(context.spell)): return {"error":"Invalid cast request."}
	if not context.get("active") is Array or context.active.size()>4: return {"error":"Invalid active effects."}
	for effect in context.active:
		if not effect is Array or effect.size()!=2: return {"error":"Invalid active effect."}
		for value in effect:
			if not Validation._integer(value,0,255): return {"error":"Invalid active effect field."}
	var descriptor: Array=Admission.DESCRIPTORS[int(context.spell)]
	var active: Array=context.active.duplicate(true)
	if int(descriptor[2])!=0:
		if active.size()==4: return {"error":"Active effect capacity exceeded."}
		active.append([int(context.spell),int(descriptor[2])+2])
	var flags:=int(context.flags)
	var sound: bool=(int(descriptor[3])&1)==0 and (flags&16)!=0
	if (int(descriptor[3])&1)==0: flags|=16
	var mana:=int(context.mana)
	var bar:=int(context.bar)
	if context.charge:
		mana=maxi(0,mana-int(descriptor[0]))
		var capacity: int=[2500,5000,7500][int(context.difficulty)]
		bar=(((mana<<8)/capacity)-1)&255 if mana!=0 else 0
	return {"mana":mana,"bar":bar,"flags":flags,"active":active,"sound_requested":sound}
