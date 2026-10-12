extends RefCounted
## Finite restored actor slots. One second per native corpse-counter update is an adapter.
const Base=preload("res://scripts/lol2/hive_return_population_state.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const MAX_HEALTH=400
const SPAWNS={23:Vector3.ZERO,24:Vector3.ZERO,25:Vector3.ZERO,26:Vector3.ZERO,27:Vector3.ZERO,28:Vector3.ZERO,29:Vector3.ZERO,32:Vector3.ZERO,33:Vector3.ZERO,34:Vector3.ZERO,35:Vector3.ZERO,36:Vector3.ZERO}
const TEMPLATES={21:Vector3(-1023,-235,-8185),22:Vector3(189,-140,-4949)}
static func actor(id: int) -> Dictionary:
	return {"active":false,"health":400,"position":[0.0,0.0,0.0],"windup":0.0,"cooldown":0.0,"seed":324508639+id}
static func initial() -> Dictionary:
	var result:={"version":1,"actors":{},"slots":{},"fraction":0.0,"inside":false}
	for id in SPAWNS:
		result.actors[str(id)]=actor(id)
		result.slots[str(id)]={"phase":0,"counter":0,"generation":0,"template":0,"inventory":[],"held":false}
	return result
static func validate(s: Variant) -> String:
	if not s is Dictionary or not Values.integer(s.get("version"),1) or s.version!=1 or not s.get("actors") is Dictionary or not s.get("slots") is Dictionary: return "Invalid rune population."
	if s.actors.size()!=SPAWNS.size() or s.slots.size()!=SPAWNS.size() or not s.get("inside") is bool: return "Incomplete rune actor pool."
	var fraction=s.get("fraction")
	if not (fraction is int or fraction is float) or not is_finite(float(fraction)) or fraction<0 or fraction>=1: return "Invalid retirement clock."
	for id in SPAWNS:
		var key:=str(id)
		var error:=Base.validate_actor(s.actors.get(key))
		if not error.is_empty(): return error
		var slot=s.slots.get(key)
		if not slot is Dictionary or not Values.integer(slot.get("phase"),4) or not Values.integer(slot.get("counter"),255) or not Values.integer(slot.get("generation"),65535) or not Values.integer(slot.get("template"),22) or not slot.get("held") is bool: return "Invalid reusable slot."
		if not slot.get("inventory") is Array or slot.inventory.size()>64: return "Invalid slot inventory."
		for item in slot.inventory:
			if not item is String or item.is_empty() or item.length()>128: return "Invalid slot inventory item."
		var a: Dictionary=s.actors[key]
		if slot.generation==0:
			if slot.template!=0 or slot.phase>2 or a.active: return "Original slot contains a copy."
		elif int(slot.template) not in [21,22] or slot.phase<2 or not a.active: return "Copied slot lost its identity."
		if slot.phase==2 and slot.counter!=0: return "Reusable slot retains retirement counter."
		if slot.phase==3 and (a.health<=0 or slot.counter!=0): return "Living copy has invalid retirement state."
		if slot.phase==4 and a.health!=0: return "Living copy marked dead."
		if slot.generation>0 and slot.phase==2 and a.health!=0: return "Living copy marked reusable."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var result:=Base.canonical(s)
	result.fraction=float(result.fraction)
	for slot in result.slots.values():
		for key in ["phase","counter","generation","template"]: slot[key]=int(slot[key])
	return result
static func observe(s: Dictionary, dead: Dictionary) -> void:
	for id in SPAWNS:
		var key:=str(id);var slot: Dictionary=s.slots[key]
		if slot.phase==0 and dead.get(key,false):
			slot.phase=1;slot.counter=3 if id in [35,36] else 5
		elif slot.phase==3 and s.actors[key].health==0:
			slot.phase=4;slot.counter=5 # Copies are HIVEW even in an EXEC source slot.
static func advance(s: Dictionary, delta: float, corpse_ready: Dictionary) -> Array:
	var retired: Array=[]
	if not is_finite(delta) or delta<=0: return retired
	var pending:=false
	for slot in s.slots.values():
		if slot.phase in [1,4]: pending=true
	if not pending: return retired
	s.fraction+=delta
	while s.fraction>=1:
		s.fraction-=1
		var cleanup_used:=false
		for id in SPAWNS:
			var key:=str(id);var slot: Dictionary=s.slots[key]
			if slot.phase not in [1,4]: continue
			if slot.counter not in [0,255]: slot.counter=maxi(int(slot.counter)-1,1 if slot.held else 0)
			var ready: bool=corpse_ready.get(key,false) if slot.phase==1 else s.actors[key].get("death_animation",{}).get("corpse",false)
			if slot.counter==0 and ready and not cleanup_used and slot.inventory.is_empty():
				slot.phase=2;retired.append(id);cleanup_used=true
	return retired
static func summon(s: Dictionary, has_runes: bool) -> Array:
	var spawned: Array=[]
	if not has_runes: return spawned
	for template in [22,21]:
		for id in SPAWNS:
			var key:=str(id);var slot: Dictionary=s.slots[key]
			if slot.phase!=2 or slot.generation>=65535: continue
			# Preserve destination inventory and slot identity across the copy.
			slot.phase=3;slot.generation+=1;slot.template=template;slot.held=false
			var a:=actor(id);var p: Vector3=TEMPLATES[template]
			a.active=true;a.position=[p.x,p.y,p.z];a.seed=(324508639+id+int(slot.generation))&0x7fffffff
			s.actors[key]=a;spawned.append({"slot":id,"template":template,"generation":slot.generation})
			break
	return spawned
static func arrive(s: Dictionary, quests: Dictionary) -> Array:
	return summon(s,quests.get("monastery",{}).get("globals",{}).get("GV_HAS_RUNES",0)==1)
