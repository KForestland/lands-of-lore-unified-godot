extends RefCounted
## Six source switch bodies, ending at A9517. The caller supplies whether an
## effect instance was allocated; constructors still belong to the effect owner.
const Target=preload("res://scripts/lol2/dawn_cast_target.gd")
const ARGUMENTS={7:["instance","owner","target","alternate"],32:["instance","owner","target",1,"alternate"],
	39:["instance","owner","target",1800<<16],40:["instance","owner","target",1800<<16],
	50:["instance","owner","target"],58:["instance","owner","target","alternate",1,4]}
static func plan(context: Variant) -> Dictionary:
	if not context is Dictionary or not context.get("allocated") is bool: return {"error":"Invalid cast allocation context."}
	for pair in [["spell",255],["heading",65535],["saved_heading",65535],["exclusive",255]]:
		if not Target.integer(context.get(pair[0]),0,pair[1]):return {"error":"Invalid cast dispatch field: "+pair[0]}
	var spell:=int(context.spell)
	if not ARGUMENTS.has(spell):return {"error":"Unsupported Dawn cast dispatch."}
	# Both shield variants claim the exclusive slot BEFORE allocation succeeds.
	var exclusive:=spell if spell in [39,40] else int(context.exclusive)
	var heading:=int(context.saved_heading) if spell in [39,40,50] else int(context.heading)
	return {"heading":heading,"exclusive":exclusive,"construct":bool(context.allocated),"completion_reached":true,
		"arguments":ARGUMENTS[spell].duplicate() if context.allocated else []}
