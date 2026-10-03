extends RefCounted
## Source identities and pending decisions. World perception/movement are separate.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Choice=preload("res://scripts/lol2/hive_ai_action_choice.gd")
const SOURCE="res://scripts/lol2/cave_roach_population_source.json"
static func initial() -> Dictionary:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var actors: Dictionary={}
	for row in source.actors:
		actors[str(int(row.actor))]={"health":10,"position":row.position.duplicate(),"stats":source.stats.map(func(n):return int(n)),"a8":14,"a9":14,"aa":9,"ab":9,"b5":0,"b8":1,"b9":0,"ba":0,"bb":0,"word7c":0}
	return {"version":1,"actors":actors,"regions":[]}
static func validate(state: Variant) -> String:
	if not state is Dictionary or not Values.integer(state.get("version"),1) or state.version!=1 or not state.get("actors") is Dictionary: return "Invalid cave Roach population."
	var expected: Dictionary=initial().actors
	if state.actors.size()!=expected.size(): return "Incomplete cave Roach identities."
	for id in expected:
		var actor=state.actors.get(id)
		if not actor is Dictionary or not Values.integer(actor.get("health"),10) or not Values.vector(actor.get("position"),32768): return "Invalid cave Roach actor."
		if not actor.get("stats") is Array or actor.stats.size()!=30: return "Invalid cave Roach stat bank."
		for stat in actor.stats:
			if not Values.integer(stat,255): return "Invalid cave Roach stat."
		for field in ["a8","a9","aa","ab","b5","b8","b9","ba","bb"]:
			if not Values.integer(actor.get(field),255): return "Invalid cave Roach decision byte."
		if not Values.integer(actor.get("word7c"),65535): return "Invalid cave Roach counter."
		if actor.a8>15 or actor.a9>15 or actor.aa>17 or actor.ab>17: return "Invalid cave Roach decision selector."
		if (actor.health==0)!=(actor.a8==15): return "Cave Roach defeat disagrees with behavior."
	if state.has("visuals"):
		if not state.visuals is Dictionary or state.visuals.size()!=expected.size(): return "Incomplete cave Roach visuals."
		for id in expected:
			var v=state.visuals.get(id)
			if not v is Dictionary or not Values.integer(v.get("action"),14) or int(v.action) not in [0,9,14]: return "Invalid cave Roach visual action."
			var elapsed=v.get("elapsed")
			var duration:=1.0 if v.action==9 else 2.5 if v.action==14 else 0.0
			if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>duration: return "Invalid cave Roach visual clock."
			if v.action==9 and elapsed>=duration: return "Completed cave Roach startup remains active."
			if (state.actors[id].health==0)!=(v.action==14): return "Cave Roach death presentation disagrees."
	if not state.get("regions") is Array or state.regions.size()>2: return "Invalid cave Roach region history."
	var seen: Array=[]
	for region in state.regions:
		if not Values.integer(region,1358) or int(region) not in [1140,1358] or int(region) in seen: return "Invalid cave Roach region history."
		seen.append(int(region))
	return ""
static func canonical(state: Dictionary) -> Dictionary:
	var result:=state.duplicate(true)
	result.version=1
	result.regions=result.regions.map(func(n):return int(n))
	for actor in result.actors.values():
		for field in ["health","a8","a9","aa","ab","b5","b8","b9","ba","bb","word7c"]:actor[field]=int(actor[field])
		actor.stats=actor.stats.map(func(n):return int(n))
		actor.position=actor.position.map(func(n):return float(n))
	if result.has("visuals"):
		for v in result.visuals.values():
			v.action=int(v.action);v.elapsed=float(v.elapsed)
	return result

static func initialize_visuals(state: Dictionary) -> void:
	if state.has("visuals"): return
	state.visuals={}
	for id in state.actors:
		var dead: bool=state.actors[id].health==0
		# Old defeated packets stay defeated and do not replay a collapse.
		state.visuals[id]={"action":14 if dead else 9,"elapsed":2.5 if dead else 0.0}

static func advance_visuals(state: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	initialize_visuals(state)
	for v in state.visuals.values():
		if v.action==9:
			v.elapsed=minf(1.0,v.elapsed+delta)
			if v.elapsed>=1.0: v.action=0;v.elapsed=0.0
		elif v.action==14: v.elapsed=minf(2.5,v.elapsed+delta)

static func damage(state: Dictionary, id: String, amount: int) -> int:
	if amount<=0 or not state.actors.has(id): return 0
	var actor: Dictionary=state.actors[id]
	var loss:=mini(int(actor.health),amount)
	if loss==0: return 0
	initialize_visuals(state)
	actor.health-=loss
	if actor.health==0:
		actor.a8=15;actor.a9=15;actor.aa=14;actor.ab=14
		state.visuals[id]={"action":14,"elapsed":0.0}
	return loss
static func first_contact(state: Dictionary, region: int) -> bool:
	if region not in [1140,1358] or region in state.regions: return false
	state.regions.append(region)
	# Both original groups set property13 then7 for these exact twelve actors.
	for id in [27,30,26,25,29,28,33,31,43,34,35,32]:
		var actor: Dictionary=state.actors[str(id)]
		if actor.a8==15: continue
		actor.b5=(int(actor.b5)|12)&254;actor.word7c=0
	return true
static func contact_at(state: Dictionary, regions: Array, point: Vector3, grounded: bool) -> void:
	if not grounded: return
	var foot: float=point.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for region in regions:
		if int(region.region) in state.regions or foot<region.floor_min-1 or foot>region.floor_max+3: continue
		var polygon:=PackedVector2Array()
		for vertex in region.polygon: polygon.append(Vector2(vertex[0],vertex[1]))
		if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon): first_contact(state,int(region.region))
static func apply_pending(state: Dictionary, id: String, goal: int, action: int) -> bool:
	if not state.actors.has(id) or goal<0 or goal>13 or action<0 or action>14: return false
	var actor: Dictionary=state.actors[id]
	if actor.health==0 or (int(actor.b5)&1)!=0: return false
	if (int(actor.b5)&4)!=0: actor.a9=goal
	if (int(actor.b5)&8)!=0: actor.ab=action
	return true
static func choose_pending(state: Dictionary, id: String, stats: Variant, goal_chooser: RefCounted, action_chooser: RefCounted) -> Dictionary:
	if not state.actors.has(id): return {"error":"Unknown cave Roach identity."}
	var actor: Dictionary=state.actors[id]
	if actor.health==0: return {"error":"Defeated cave Roach cannot choose."}
	if goal_chooser==null or action_chooser==null: return {"error":"Cave Roach choice profile unavailable."}
	# Same supplied effective bank for both selections; action sees the new goal.
	# Commit remains separate. Never save half a decision if action scoring fails.
	var goal_result: Dictionary=goal_chooser.update_pending(actor,stats)
	if goal_result.has("error"): return goal_result
	var action_result: Dictionary=action_chooser.update_pending(goal_result.state,stats)
	if action_result.has("error"): return action_result
	state.actors[id]=action_result.state.duplicate(true)
	return {"chosen":goal_result.chosen or action_result.chosen,"goal":goal_result,"action":action_result}
static func commit(state: Dictionary, id: String, mode: int) -> bool:
	if not state.actors.has(id): return false
	var actor: Dictionary=state.actors[id]
	if actor.health==0: return false
	var result:=Choice.commit_postdecision(actor,mode)
	if result.has("error"): return false
	state.actors[id]=result.state
	return result.committed
