extends RefCounted
## Props316/318 -> actors33/35. Source callback order; local seconds are adapters.
const Attack=preload("res://scripts/lol2/hive_warrior_attack.gd")
const Death=preload("res://scripts/lol2/hive_warrior_death.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const SPAWNS := {33:Vector3(-4796,-3000,-6374),35:Vector3(-2562,-619,-8201)}
const HEALTH := {33:400,35:300}
const UNFOLD := 25.0/15.0
const EATING := 54.0/15.0
const RISE := 17.0/15.0
static func initial() -> Dictionary:
	var actors: Dictionary={}
	for id in SPAWNS:
		var p: Vector3=SPAWNS[id]
		actors[str(id)]={"active":false,"health":HEALTH[id],"position":[p.x,p.y,p.z],"windup":0.0,"cooldown":0.0,"seed":324508639+id,"phase":0,"elapsed":0.0}
	return {"version":1,"actors":actors,"local7":0,"contact716":false,"feeding_hit_disabled":false}
static func validate(s: Variant) -> String:
	if not s is Dictionary or s.get("version")!=1 or not s.get("actors") is Dictionary or s.actors.size()!=2: return "Invalid Hive ambush state."
	if not Values.integer(s.get("local7"),1) or not s.get("contact716") is bool: return "Invalid Hive ambush history."
	if not s.get("feeding_hit_disabled",false) is bool: return "Invalid feeding hit history."
	for id in SPAWNS:
		var a=s.actors.get(str(id))
		if not a is Dictionary or not a.get("active") is bool: return "Invalid ambush actor."
		if not Values.integer(a.get("health"),HEALTH[id]) or not Values.integer(a.get("seed"),0x7fffffff): return "Invalid ambush health or RNG."
		if not Values.vector(a.get("position"),32768) or not Values.integer(a.get("phase"),3): return "Invalid ambush position or phase."
		if id==33 and a.phase==2: return "Unfold has no second clip."
		if a.active!=(a.phase==3): return "Ambush activation disagrees with its film."
		for key in ["elapsed","windup","cooldown"]:
			var n=a.get(key)
			if not (n is int or n is float) or not is_finite(float(n)) or n<0: return "Invalid ambush clock."
		if a.windup>=1.2 or a.cooldown>0.8: return "Invalid ambush attack clock."
		if (a.phase==3 or (id==33 and a.phase==0)) and a.elapsed!=0: return "Inactive ambush clip progressed."
		if a.phase!=3 and a.elapsed>=(UNFOLD if id==33 else RISE if a.phase==2 else EATING): return "Ambush clip already ended."
		if not a.active and (a.health!=HEALTH[id] or a.windup!=0 or a.cooldown!=0): return "Inactive ambush actor changed."
		if a.has("warrior_mask") and (id!=33 or not Values.integer(a.warrior_mask,4) or int(a.warrior_mask) not in [1,2,4]): return "Invalid warrior health mask."
		if a.has("attack_animation"):
			if id!=33 or not a.active or a.health<=0 or a.windup!=0 or a.cooldown!=0 or not Attack.validate(a.attack_animation).is_empty(): return "Invalid warrior attack animation."
		if a.has("death_animation"):
			if id!=33 or a.health!=0 or not a.active or not Death.validate(a.death_animation).is_empty(): return "Invalid warrior death animation."
		if a.health==0 and a.windup!=0: return "Defeated ambush actor is attacking."
	if (s.local7==1)!=(s.actors["33"].phase!=0): return "Unfold latch disagrees with its film."
	if s.contact716 and s.actors["35"].phase==0: return "Contact did not arm the feeding Executioner."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var result:=s.duplicate(true)
	result.version=1;result.local7=int(result.local7)
	result.feeding_hit_disabled=bool(result.get("feeding_hit_disabled",false))
	for a in result.actors.values():
		for key in ["health","seed","phase"]: a[key]=int(a[key])
		for key in ["elapsed","windup","cooldown"]: a[key]=float(a[key])
		a.position=a.position.map(func(n): return float(n))
		if a.has("warrior_mask"): a.warrior_mask=int(a.warrior_mask)
		if a.has("attack_animation"): a.attack_animation=Attack.canonical(a.attack_animation)
		if a.has("death_animation"): a.death_animation=Death.canonical(a.death_animation)
	return result
static func arm(s: Dictionary, id: int, contact: bool=false) -> bool:
	if id not in SPAWNS: return false
	if id==35 and contact:
		if s.contact716: return false
		s.contact716=true
	var a: Dictionary=s.actors[str(id)]
	if a.phase!=0: return false
	a.phase=1
	if id==33: s.local7=1;a.elapsed=0.0
	return true
static func spark_feeding(s: Dictionary) -> bool:
	if s.get("feeding_hit_disabled",false) or s.actors["35"].phase not in [0,1,2]: return false
	# Native level5/current prop318 exception suppresses group4022.
	s.feeding_hit_disabled=true
	return true
static func advance(s: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	for id in SPAWNS:
		var a: Dictionary=s.actors[str(id)]
		if a.phase==3 or (id==33 and a.phase==0): continue
		var remaining:=delta
		if id==35 and a.phase==1:
			# Same documented next-loop first-frame convention as prop317.
			var wait:=0.0 if a.elapsed==0 else EATING-float(a.elapsed)
			if remaining<wait: a.elapsed+=remaining;continue
			remaining-=wait;a.phase=2;a.elapsed=0.0
		if id==35 and a.phase==0:
			a.elapsed=fmod(float(a.elapsed)+remaining,EATING)
		else:
			a.elapsed+=remaining
			if a.elapsed>=(UNFOLD if id==33 else RISE):
				a.phase=3;a.elapsed=0.0;a.active=true
