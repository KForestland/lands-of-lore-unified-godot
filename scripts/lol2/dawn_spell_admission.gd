extends RefCounted
## Native A7E4C for Dawn's six source candidates. Does not choose or cast a spell.
const Validation=preload("res://scripts/lol2/hive_player_conditions.gd")
const DESCRIPTORS={7:[40,8,1,32],32:[40,8,0,32],39:[10,5,30,225],40:[20,7,30,225],50:[50,2,0,33],58:[30,5,0,32]}
static func admit(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid spell admission context."}
	var bounds:={"spell":255,"w88":65535,"mana":65535,"check_cost":1,"target":4294967295,"seen":255,"b7":255,"b8":4294967295,"distance":255,"exclusive":255,"write_reason":1,"previous_reason":255}
	for field in bounds:
		if not Validation._integer(context.get(field),0,bounds[field]): return {"error":"Invalid admission field: "+field}
	if not context.get("active") is Array or context.active.size()>4: return {"error":"Invalid active spell list."}
	for spell in context.active:
		if not Validation._integer(spell,0,255): return {"error":"Invalid active spell."}
	if not DESCRIPTORS.has(int(context.spell)): return {"error":"Unsupported Dawn spell."}
	var desc: Array=DESCRIPTORS[int(context.spell)]
	var reason:=0
	var flags:=int(context.b8)
	if int(context.w88)==0: reason=3
	elif int(context.check_cost)!=0 and int(context.mana)<int(desc[0]): reason=5
	elif (int(desc[3])&1)==0:
		if int(context.target)==0: reason=6
		elif (int(context.seen)&5)==0:
			if (int(context.b7)&8)==0: reason=7
			elif (flags&0x30)!=0x10: reason=8
			elif int(context.target)!=0x22574 or int(context.distance)<=127: reason=9
			else: flags|=0x40
	if reason==0:
		if (int(desc[3])&0x40)!=0 and int(context.exclusive)!=0: reason=10
		elif int(desc[2])!=0 and context.active.size()>=4: reason=11
		elif context.active.any(func(spell): return int(spell)==int(context.spell)): reason=12
	return {"accepted":reason==0,"reason":reason,"stored_reason":reason if int(context.write_reason)!=0 else int(context.previous_reason),"b8":flags}
