extends RefCounted
## Source identities and pending decisions. World perception/movement are separate.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Choice=preload("res://scripts/lol2/hive_ai_action_choice.gd")
const FPS:=8.0
const Audio=preload("res://scripts/lol2/scripted_creature_audio_state.gd")
static func audio_contract() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_roach_audio_source.json"))
static func audio_actors() -> Array:
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string(SOURCE)).actors
	for row in rows: row.definition=4
	return rows
const SOURCE="res://scripts/lol2/cave_roach_population_source.json"
## Live behavior adapter (docs/cave-roach-population-live.md). Damage7 at selector6
## frame12 is native-derived (docs/cave-roach-attack.json); perception range, reach,
## speed and the8fps clip clock reuse the accepted entrance-Roach adapters.
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const IDLE:=Live.IDLE
const PURSUE:=Live.PURSUE
const ATTACK:=Live.ATTACK
const ALERT_RANGE:=180.0
const REACH:=40.0
const SPEED:=42.0
const DAMAGE:=7
const IMPACT_SECONDS:=12.0/8.0
const ATTACK_SECONDS:=16.0/8.0
## Playable damage = Live.playable_damage(DAMAGE) (asserted in cave_roach_live_state_test).
const RULES:={"alert":ALERT_RANGE,"reach":REACH,"damage":3,"impact":IMPACT_SECONDS,"clip":ATTACK_SECONDS}
## Owner F10 r12l 2026-10-28 15:20:52 ("and died here"): in the crate room two source spawns lie inside the port's crate
## solids (actor 33 in crate 122, actor 34 in crate 96; static_collision_L1_DC), hidden but in biting reach. They start
## at the nearest free spot instead (ring search, 12 and 16 units away). Whether native crates block creatures is not
## traced; saves made before this keep their stored positions. Modern adapter: docs/DEVIATIONS.md.
const SPAWN_CLEAR:={"33":[620.0,-215.0,-12263.0],"34":[667.0,-215.0,-12244.0]}
static func initial() -> Dictionary:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var actors: Dictionary={}
	for row in source.actors:
		var id:=str(int(row.actor))
		actors[id]={"health":10,"position":SPAWN_CLEAR.get(id,row.position).duplicate(),"stats":source.stats.map(func(n):return int(n)),"a8":14,"a9":14,"aa":9,"ab":9,"b5":0,"b8":1,"b9":0,"ba":0,"bb":0,"word7c":0}
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
	if state.has("live"):
		if not state.live is Dictionary or state.live.size()!=expected.size(): return "Incomplete cave Roach live packets."
		for id in expected:
			var live_error:=Live.validate(state.live.get(id),state.actors[id].health>0,RULES)
			if not live_error.is_empty(): return live_error
	if state.has("audio"):
		var error:=Audio.validate(state.audio,audio_actors(),audio_contract())
		if not error.is_empty(): return error
	if not state.get("regions") is Array or state.regions.size()>2: return "Invalid cave Roach region history."
	var seen: Array=[]
	for region in state.regions:
		if not Values.integer(region,1358) or int(region) not in [1140,1358] or int(region) in seen: return "Invalid cave Roach region history."
		seen.append(int(region))
	if state.has("ai"):
		var ai=state.ai
		if not ai is Dictionary or ai.size()!=2 or not ai.get("last_hit") is String or (not ai.last_hit.is_empty() and not expected.has(ai.last_hit)): return "Invalid cave Roach disposition."
		var clock=ai.get("clock")
		if not (clock is int or clock is float) or not is_finite(float(clock)) or clock<0 or clock>=1: return "Invalid cave Roach disposition clock."
	return ""
## Save packet: the attack-history clock is written on the project's 1/1024 s grid (the only
## grid Godot JSON round-trips exactly; see creature_live_rules.gd). It is floored once per save,
## not per update, so decay stays independent of physics Hz; a load resumes from the saved grid value.
static func saved(state: Dictionary) -> Dictionary:
	var result:=state.duplicate(true)
	if result.has("ai"): result.ai.clock=floorf(float(result.ai.clock)*1024.0)/1024.0
	return result
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
	if result.has("live"):
		for live in result.live.values():
			live.mode=int(live.mode);live.elapsed=float(live.elapsed)
			if live.has("cooldown"): live.cooldown=float(live.cooldown)
			live.heading=int(live.heading)
	if result.has("audio"): result.audio=Audio.canonical(result.audio)
	if result.has("ai"): result.ai={"last_hit":str(result.ai.last_hit),"clock":float(result.ai.clock)}
	return result

static func initialize_visuals(state: Dictionary) -> void:
	if state.has("visuals"): return
	state.visuals={}
	for id in state.actors:
		var dead: bool=state.actors[id].health==0
		# Old defeated packets stay defeated and do not replay a collapse.
		# Behavior14 requests action0, despite retaining native current-action byte9.
		state.visuals[id]={"action":14 if dead else 0,"elapsed":2.5 if dead else 0.0}

static func advance_visuals(state: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	initialize_visuals(state)
	for v in state.visuals.values():
		if v.action==9:
			v.elapsed=minf(1.0,v.elapsed+delta)
			if v.elapsed>=1.0: v.action=0;v.elapsed=0.0
		elif v.action==14: v.elapsed=minf(2.5,v.elapsed+delta)

## The twelve nest actors are the only ones addressed by source decision-enable
## writes (regions1140/1358 property13/7 set B5 0x0C); until then they stay dormant.
const NEST:=[25,26,27,28,29,30,31,32,33,34,35,43]
static func dormant(state: Dictionary, id: String) -> bool:
	return int(id) in NEST and (int(state.actors[id].b5)&12)==0

static func damage(state: Dictionary, id: String, amount: int) -> int:
	if amount<=0 or not state.actors.has(id): return 0
	var actor: Dictionary=state.actors[id]
	var loss:=mini(int(actor.health),amount)
	if loss==0: return 0
	# Being hit rouses a dormant nest actor (modern adapter, as for Museum skeletons).
	if dormant(state,id): actor.b5=(int(actor.b5)|12)&254
	initialize_visuals(state)
	actor.health-=loss
	if actor.health==0:
		actor.a8=15;actor.a9=15;actor.aa=14;actor.ab=14
		state.visuals[id]={"action":14,"elapsed":0.0}
		if state.has("live"):
			state.live[id].merge({"mode":IDLE,"elapsed":0.0,"hit":false},true);state.live[id].erase("cooldown")
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

## Facing is saved as the source16-bit heading unit so disk/JSON round trips are exact.
static func heading_units(facing: Vector2) -> int: return Live.heading_units(facing)
static func heading_vector(units: int) -> Vector2: return Live.heading_vector(units)
static func initialize_live(state: Dictionary) -> void:
	if state.has("live"): return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	state.live={}
	for row in source.actors:
		state.live[str(int(row.actor))]={"mode":IDLE,"elapsed":0.0,"hit":false,"heading":int(row.heading)}

## One bounded step. Returns player damage dealt (0 or DAMAGE-capped). An attack
## clip always completes and lands at most once; only the impact frame checks reach.
static func advance_live(state: Dictionary, id: String, delta: float, distance: float, sight: bool, protected: bool, player_health: int, defense: int = 0) -> int:
	if not state.actors.has(id): return 0
	initialize_live(state)
	var rules:=RULES.duplicate()
	rules.damage=preload("res://scripts/lol2/player_defense.gd").damage(DAMAGE,defense)
	return Live.advance(state.live[id],state.actors[id].health>0,delta,distance,sight,protected,player_health,rules)

## Native disposition (docs/cave-roach-disposition.md, ROACH_BEHAVIOUR_DECODE_20261028 s5). Each decision AA208
## scores the goal from a temporary bank: persistent stats + the current goal's globalai row + the Roach effector
## row of every true condition. Bound here: the health band (5+stat4/64), condition 45+stat25/64, condition 0 (this
## is the creature the player last hit) and, while the Roach perceives the player, the form condition 19/20/21
## (player +0x1AB == 2 lizard / 0 human / 1 beast). Other conditions are not bound (their sampled effect never
## changes the engaged result). Perception itself stays the existing range+sight adapter.
const AI_SOURCE:="res://scripts/lol2/cave_roach_ai_source.json"
const GOAL_DESTROY:=4
const GOAL_GET_PLAYER:=5
const GOAL_WANDER:=6
const GOAL_FLEE:=10
const ATTACKED_STAT:=1
static var _ai: Dictionary={}
static func _ai_tables() -> Dictionary:
	if _ai.is_empty():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(AI_SOURCE))
		var goal:=preload("res://scripts/lol2/hive_ai_goal_choice.gd").new()
		assert(goal.configure(data.goals).is_empty())
		_ai={"goal":goal,"adjustments":data.adjustments}
	return _ai
## Native: player +0x1AB form 2 lizard / 0 human / 1 beast -> conditions 19/20/21 (proven, decode s5/s6). All three
## rows apply (owner 2026-10-29 r4: "if they attack the lizard that is ok"): a perceiving Roach chooses Destroy
## against a lizard and Wander against a human or beast.
const NATIVE_FORM_CONDITIONS:={2:19,0:20,1:21}
static func form_condition(form: int) -> int:
	return NATIVE_FORM_CONDITIONS.get(form,-1)
static func effective_bank(state: Dictionary, id: String, form: int, perceives: bool) -> Array:
	var actor: Dictionary=state.actors[id]
	var adjust: Dictionary=_ai_tables().adjustments
	var goal:=int(actor.a8)
	var conditions: Array=[5+mini(3,int(actor.stats[4])/64),45+mini(3,int(actor.stats[25])/64)]
	if state.has("ai") and state.ai.last_hit==id: conditions.append(0)
	if perceives and form_condition(form)>=0: conditions.append(form_condition(form))
	conditions.sort()
	var bank: Array=actor.stats.map(func(n):return int(n))
	var rows: Array=[]
	if goal<14: rows.append(adjust.goals[goal])
	for c in conditions: rows.append(adjust.conditions[c])
	for row in rows:
		for i in range(30): bank[i]=clampi(bank[i]+int(row[i]),0,255)
	return bank
## Chooses and commits the goal (a8/a9). Returns the goal; a defeated Roach returns 15.
static func dispose(state: Dictionary, id: String, form: int, perceives: bool) -> int:
	var actor: Dictionary=state.actors[id]
	if actor.health==0: return 15
	var previous:=int(actor.a8) if int(actor.a8)<=14 else 14
	var result: Dictionary=_ai_tables().goal.choose(effective_bank(state,id,form,perceives),previous)
	if result.has("error"): return previous
	actor.a8=int(result.goal);actor.a9=int(result.goal)
	return actor.a8
static func hostile(goal: int) -> bool:
	return goal in [GOAL_DESTROY,GOAL_GET_PLAYER]
## 0xA7234-0xA724F: a landed player hit sets "Attacked by player before" to 255 and makes this the last-hit creature.
static func player_hit(state: Dictionary, id: String) -> void:
	if not state.actors.has(id) or state.actors[id].health==0: return
	state.actors[id].stats[ATTACKED_STAT]=255
	if not state.has("ai"): state.ai={"last_hit":"","clock":0.0}
	state.ai.last_hit=id
## 0xAB5EC-0xAB5F7: the slow update lowers it by one per game second.
static func advance_ai(state: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	if not state.has("ai"): state.ai={"last_hit":"","clock":0.0}
	var clock:=float(state.ai.clock)+delta
	# Preserve elapsed fractions; quantizing each update makes decay depend on physics Hz.
	# Correct only floating-point error at an exact second boundary.
	var seconds:=int(floor(clock+0.000000001))
	state.ai.clock=maxf(0.0,clock-seconds)
	if seconds<=0: return
	for actor in state.actors.values():
		if actor.health>0 and int(actor.stats[ATTACKED_STAT])>0: actor.stats[ATTACKED_STAT]=maxi(0,int(actor.stats[ATTACKED_STAT])-seconds)
## The live step behind the disposition: a hostile goal runs the existing pursue/bite adapter; any other goal
## never pursues or bites (an attack clip already started still completes, as the shared step guarantees).
static func advance_disposed(state: Dictionary, id: String, delta: float, distance: float, sight: bool, protected: bool, player_health: int, defense: int, form: int) -> Dictionary:
	if not state.actors.has(id): return {"damage":0,"goal":15}
	initialize_live(state)
	var goal:=dispose(state,id,form,sight and distance<=ALERT_RANGE)
	var live: Dictionary=state.live[id]
	if hostile(goal) or live.mode==ATTACK:
		return {"damage":advance_live(state,id,delta,distance,sight if hostile(goal) else false,protected,player_health,defense),"goal":goal}
	live.mode=IDLE;live.elapsed=0.0;live.hit=false
	return {"damage":0,"goal":goal}

## Scurry adapter leg (native action-0 movement is untraced; DEVIATIONS 2026-10-29 r4). Seeded by actor id and leg
## count, so a run is repeatable. `away` is the unit direction from the player to the Roach when the Roach perceives
## the player (the same perception that feeds dispose), else ZERO; `back` is the vector to its spawn. A perceiving
## Roach never pauses and runs within 60 degrees of straight away. Outside the leash any leg turns toward the spawn,
## and a scared leg that would lead further out keeps only its part across the line to the spawn.
static func wander_leg(id: String, count: int, away: Vector3, back: Vector3, leash: float) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash([id,count])
	if away!=Vector3.ZERO:
		var angle:=atan2(away.x,away.z)+rng.randf_range(-PI/3.0,PI/3.0)
		var heading:=Vector3(sin(angle),0,cos(angle))
		if back.length()>leash and heading.dot(back)<0:
			var home:=back.normalized()
			heading=heading-home*heading.dot(home)
			heading=home if heading.length()<0.001 else heading.normalized()
		return {"heading":heading,"left":rng.randf_range(0.8,2.4)}
	if back.length()>leash: return {"heading":back.normalized(),"left":1.5}
	if rng.randf()<0.35: return {"heading":Vector3.ZERO,"left":rng.randf_range(0.5,1.5)}
	var turn:=rng.randf()*TAU
	return {"heading":Vector3(sin(turn),0,cos(turn)),"left":rng.randf_range(0.8,2.4)}
