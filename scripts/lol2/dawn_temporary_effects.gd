extends RefCounted
## Original shield39/40 update and heal50 completed-cycle transition.
## Owner mutation, retirement and animation advance remain caller responsibilities.
const Validation=preload("res://scripts/lol2/hive_player_conditions.gd")
static func shield(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid shield update."}
	for field in ["spell","cancel","blocked"]:
		if not Validation._integer(context.get(field),0,255): return {"error":"Invalid shield byte."}
	if int(context.spell) not in [39,40] or not context.get("alive") is bool: return {"error":"Invalid shield owner."}
	for field in ["remaining","delta"]:
		if not Validation._integer(context.get(field),0,0x7fffffff): return {"error":"Invalid shield clock."}
	if not Validation._integer(context.get("unlinked"),0,0xffffffff): return {"error":"Invalid owner flags."}
	var remaining:=int(context.remaining)-int(context.delta)
	var retired: bool=remaining<=0 or not context.alive or (int(context.cancel)&2)!=0 or (int(context.unlinked)&0x1000)!=0 or (int(context.blocked)&1)!=0
	return {"remaining":remaining&0xffffffff,"retired":retired,"exclusive":0 if retired else int(context.spell)}
static func shield_frame_end(spell: Variant, mode: Variant) -> Dictionary:
	if not Validation._integer(spell,0,255) or int(spell) not in [39,40] or not Validation._integer(mode,0,255): return {"error":"Invalid shield animation."}
	var first:=0 if int(spell)==39 else 10
	return {"mode":first+1 if int(mode)==first else int(mode),"frame":0}
static func heal_cycle(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid heal cycle."}
	for field in ["cancel","ownerflag","b6","frame"]:
		if not Validation._integer(context.get(field),0,255): return {"error":"Invalid heal flag."}
	if not Validation._integer(context.get("cycles"),1,3) or not Validation._integer(context.get("health"),0,32767): return {"error":"Invalid heal owner/counter."}
	var cycles:=int(context.cycles)
	var flags:=int(context.b6)
	var eligible: bool=(int(context.cancel)&2)==0 and (int(context.ownerflag)&16)==0 and int(context.health)>0
	var heal_target: Variant=null
	if eligible:
		cycles-=1
		if cycles==0:
			heal_target=int(context.health)+50
			flags&=254
	return {"cycles":cycles,"b6":flags,"retired":not eligible or cycles==0,"frame":1 if eligible else int(context.frame),"heal_target":heal_target}
