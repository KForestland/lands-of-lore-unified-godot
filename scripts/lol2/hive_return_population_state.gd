extends RefCounted
## Source prop76 groups366/390. Arrival scheduling and combat cadence are adapters.
const Attack=preload("res://scripts/lol2/hive_warrior_attack.gd")
const Death=preload("res://scripts/lol2/hive_warrior_death.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const GROUPS := {366:[27,29,28],390:[25,26,24,23]}
const SPAWNS := {23:Vector3(-1760,-1659,-6407),24:Vector3(-2197,-1579,-7219),25:Vector3(-556,-235,-6181),26:Vector3(-3,-235,-7758),27:Vector3(-1811,-235,-7624),28:Vector3(-681,-245,-6705),29:Vector3(178,-180,-5503)}
const MAX_HEALTH := 400
static func initial() -> Dictionary:
	var actors := {}
	for id in SPAWNS:
		var p: Vector3=SPAWNS[id]
		actors[str(id)]={"active":false,"health":MAX_HEALTH,"position":[p.x,p.y,p.z],"windup":0.0,"cooldown":0.0,"seed":324508639+id}
	return {"version":1,"actors":actors}
static func validate(s: Variant) -> String:
	if not s is Dictionary or s.get("version")!=1 or not s.get("actors") is Dictionary or s.actors.size()!=SPAWNS.size(): return "Invalid Hive return population."
	for id in SPAWNS:
		var error:=validate_actor(s.actors.get(str(id)))
		if not error.is_empty(): return error
	return ""
static func validate_actor(a: Variant) -> String:
	if not a is Dictionary or not a.get("active") is bool: return "Invalid return warrior."
	if not Values.integer(a.get("health"),MAX_HEALTH): return "Invalid return warrior health."
	if not Values.integer(a.get("seed"),0x7fffffff): return "Invalid return warrior RNG."
	if not Values.vector(a.get("position"),32768): return "Invalid return warrior position."
	for key in ["windup","cooldown"]:
		var n=a.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>=(1.2 if key=="windup" else 0.801): return "Invalid return warrior clock."
	if a.has("warrior_mask") and (not Values.integer(a.warrior_mask,4) or int(a.warrior_mask) not in [1,2,4]): return "Invalid warrior health mask."
	if a.has("attack_animation"):
		if not a.active or a.health<=0 or a.windup!=0 or a.cooldown!=0 or not Attack.validate(a.attack_animation).is_empty(): return "Invalid warrior attack animation."
	if a.has("death_animation"):
		if a.health!=0 or not a.active or not Death.validate(a.death_animation).is_empty(): return "Invalid warrior death animation."
	if a.health==0 and a.windup!=0: return "Defeated return warrior is attacking."
	if not a.active and (a.health!=MAX_HEALTH or a.windup!=0 or a.cooldown!=0): return "Inactive return warrior changed."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var result:=s.duplicate(true)
	result.version=1
	for id in result.actors:
		var a: Dictionary=result.actors[id]
		a.health=int(a.health);a.seed=int(a.seed)
		a.windup=float(a.windup);a.cooldown=float(a.cooldown)
		a.position=a.position.map(func(n): return float(n))
		if a.has("warrior_mask"): a.warrior_mask=int(a.warrior_mask)
		if a.has("attack_animation"): a.attack_animation=Attack.canonical(a.attack_animation)
		if a.has("death_animation"): a.death_animation=Death.canonical(a.death_animation)
	return result
static func arrive(s: Dictionary, quests: Dictionary) -> Array:
	var enabled: Array=[]
	var globals: Dictionary=quests.get("monastery",{}).get("globals",{})
	for group in GROUPS:
		if (quests.get("shared_flag_38",0) if group==366 else globals.get("GV_MET_BACATTA",0))!=1: continue
		for id in GROUPS[group]:
			var a: Dictionary=s.actors[str(id)]
			if a.active: continue # Enable does not recreate a defeated actor.
			a.active=true
			enabled.append(id)
	return enabled
