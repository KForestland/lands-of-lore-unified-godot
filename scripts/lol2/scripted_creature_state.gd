extends RefCounted
## Source-scripted creature population (creatures, cave guards): saved
## health/position/presence/wake/rise/live state, region spawn/wake commands,
## neighbour wake and an optional death counter. Every function takes the
## population source dictionary (see tools/prepare_*_population.py).
## Adapters: perception range/reach/speed, 8fps clocks, attack-variant rotation.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const FPS:=8.0
const ALERT_RANGE:=600.0 # Woken actors hunt across a room; still requires line of sight.
const REACH:=50.0
const SPEED:=48.0

static func source(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func actor_row(src: Dictionary, id: String) -> Dictionary:
	for row in src.actors:
		if str(int(row.actor))==id: return row
	return {}

## Actors with a source wake command stay dormant until it runs (or they are hit).
static func scripted_wake(src: Dictionary, id: String) -> bool:
	for region in src.regions:
		if int(id) in region.get("wake",[]).map(func(n):return int(n)): return true
	return int(id) in src.get("scripted_dormant",[]).map(func(n):return int(n))

static func clip_seconds(frames: int) -> float: return float(frames)/FPS

static func attack_rules(src: Dictionary, id: String, variant: int) -> Dictionary:
	var row:=actor_row(src,id)
	var attacks: Array=src.definitions[str(int(row.definition))].clips.attacks
	var a: Dictionary=attacks[posmod(variant,attacks.size())]
	var impacts: Array=[]
	for i in a.hits.size(): impacts.append([float(a.hits[i][0])/FPS,Live.playable_damage(int(a.damage[i]))])
	return {"alert":ALERT_RANGE,"reach":REACH,"impacts":impacts,"impact":impacts[0][0],"damage":impacts[0][1],"clip":clip_seconds(int(a.frames))}

static func initial(src: Dictionary) -> Dictionary:
	var actors: Dictionary={}
	var live: Dictionary={}
	for row in src.actors:
		var id:=str(int(row.actor))
		var woken:=not scripted_wake(src,id)
		var rise_full:=clip_seconds(int(src.definitions[str(int(row.definition))].clips.rise.frames))
		actors[id]={"health":int(row.health),"position":row.position.map(func(n):return float(n)),"death":0.0,"woken":woken,"rise":-1.0 if not woken else rise_full,"present":bool(row.present)}
		live[id]={"mode":Live.IDLE,"elapsed":0.0,"hit":false,"hits":0,"heading":int(row.heading),"attack":0}
	return {"version":1,"actors":actors,"live":live,"regions":[],"counter":0,"prop93":0}

static func validate(state: Variant, src: Dictionary) -> String:
	if not state is Dictionary or not Values.integer(state.get("version"),1) or state.version!=1: return "Invalid creature population."
	if not state.get("actors") is Dictionary or not state.get("live") is Dictionary or not state.get("regions") is Array: return "Invalid creature population."
	var expected:=initial(src)
	if state.actors.size()!=expected.actors.size() or state.live.size()!=expected.live.size(): return "Incomplete creature identities."
	for id in expected.actors:
		var actor=state.actors.get(id)
		var row:=actor_row(src,id)
		if not actor is Dictionary or not Values.integer(actor.get("health"),int(row.health)) or not Values.vector(actor.get("position"),32768) or not actor.get("woken") is bool or not actor.get("present",bool(row.present)) is bool: return "Invalid creature actor."
		if not actor.get("present",bool(row.present)) and (actor.health!=int(row.health) or float(actor.death)!=0 or int(state.live.get(id,{}).get("mode",0))!=Live.IDLE): return "Absent creature has live state."
		var death=actor.get("death");var rise=actor.get("rise")
		var death_max:=clip_seconds(int(src.definitions[str(int(row.definition))].clips.death.frames))
		if not (death is int or death is float) or not is_finite(float(death)) or death<0 or death>death_max: return "Invalid creature death clock."
		if actor.health>0 and death!=0: return "Living creature has a death clock."
		if not (rise is int or rise is float) or not is_finite(float(rise)) or rise<-1 or rise>clip_seconds(int(src.definitions[str(int(row.definition))].clips.rise.frames)): return "Invalid creature rise clock."
		if not actor.woken and rise!=-1: return "Dormant creature has a rise clock."
		var live=state.live.get(id)
		if not live is Dictionary or not Values.integer(live.get("attack"),2) or not Values.integer(live.get("hits"),2): return "Invalid creature attack variant."
		var rules:=attack_rules(src,id,int(live.attack))
		var error:=Live.validate(live,actor.health>0,rules)
		if not error.is_empty(): return error
		var ready: bool=actor.woken and rise>=clip_seconds(int(src.definitions[str(int(row.definition))].clips.rise.frames))
		if actor.health>0 and not ready and int(live.mode)!=Live.IDLE: return "Dormant or rising creature is active."
		if int(live.hits)>(0 if not live.hit else rules.impacts.size()): return "creature hit count exceeds its clip."
	var seen: Array=[]
	for region in state.regions:
		if not Values.integer(region,2000) or int(region) not in src.regions.map(func(r):return int(r.region)) or int(region) in seen: return "Invalid creature region history."
		seen.append(int(region))
	if not Values.integer(state.get("counter"),10) or not Values.integer(state.get("prop93"),3) or int(state.prop93) not in [0,3]: return "Invalid creature counter."
	if int(src.get("counter_target",0))>0 and (int(state.prop93)==3)!=(int(state.counter)>=int(src.counter_target)): return "Creature counter disagrees with its result."
	return ""

static func canonical(state: Dictionary, src: Dictionary) -> Dictionary:
	var result:=state.duplicate(true)
	result.version=1;result.counter=int(result.counter);result.prop93=int(result.prop93)
	result.regions=result.regions.map(func(n):return int(n))
	for id in result.actors:
		var actor: Dictionary=result.actors[id]
		# Packets saved before placement presence was modelled use the source flag.
		if not actor.has("present"): actor.present=bool(actor_row(src,id).present)
		actor.health=int(actor.health);actor.death=float(actor.death);actor.rise=float(actor.rise)
		actor.position=actor.position.map(func(n):return float(n))
	for live in result.live.values():
		for key in ["mode","heading","attack","hits"]: live[key]=int(live[key])
		live.elapsed=float(live.elapsed)
		if live.has("cooldown"): live.cooldown=float(live.cooldown)
	return result

## Source op9 property3 (B49EC): link an absent actor into the world.
static func spawn(state: Dictionary, id: String) -> bool:
	var actor: Dictionary=state.actors.get(id,{})
	if actor.is_empty() or actor.present: return false
	actor.present=true
	if actor.woken: actor.rise=0.0 # Appears through its action9 clip.
	return true

static func wake(state: Dictionary, id: String) -> bool:
	var actor: Dictionary=state.actors.get(id,{})
	if actor.is_empty() or actor.health<=0 or actor.woken or not actor.present: return false
	actor.woken=true;actor.rise=0.0
	return true

## Source region event2 groups (property13 then7) for the listed actors, once.
static func contact(state: Dictionary, src: Dictionary, point: Vector3, foot: float) -> Array:
	var woke: Array=[]
	for region in src.regions:
		var index:=int(region.region)
		if index in state.regions or foot<float(region.floor_min)-1 or foot>float(region.floor_max)+3: continue
		var polygon:=PackedVector2Array()
		for vertex in region.polygon: polygon.append(Vector2(vertex[0],vertex[1]))
		if not Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon): continue
		state.regions.append(index)
		for id in region.get("spawn",[]): spawn(state,str(int(id)))
		for id in region.get("wake",[]):
			if wake(state,str(int(id))): woke.append(str(int(id)))
	return woke

## Returns actual loss. Being hit wakes the actor and (24-26) its source neighbours.
static func damage(state: Dictionary, src: Dictionary, id: String, amount: int) -> int:
	if amount<=0 or not state.actors.has(id) or not state.actors[id].present: return 0
	var actor: Dictionary=state.actors[id]
	var loss:=mini(int(actor.health),amount)
	if loss==0: return 0
	wake(state,id)
	if actor.woken and actor.rise<0: actor.rise=0.0
	for other in src.get("neighbour_wake",{}).get(id,[]): wake(state,str(int(other)))
	actor.health-=loss
	if actor.health==0:
		actor.death=0.0
		state.live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false,"hits":0},true);state.live[id].erase("cooldown")
		if int(id) in src.get("counted",[]).map(func(n):return int(n)):
			state.counter=mini(int(src.counter_target),int(state.counter)+1)
			if int(state.counter)>=int(src.counter_target): state.prop93=int(src.counter_result.state)
	return loss

## Saved clocks on a 1/1024s grid (exact JSON round trip).
static func advance_clocks(state: Dictionary, src: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	for id in state.actors:
		var actor: Dictionary=state.actors[id]
		var clips: Dictionary=src.definitions[str(int(actor_row(src,id).definition))].clips
		if actor.health==0: actor.death=minf(clip_seconds(int(clips.death.frames)),snappedf(float(actor.death)+delta,1.0/1024))
		elif actor.woken and actor.rise>=0: actor.rise=minf(clip_seconds(int(clips.rise.frames)),snappedf(float(actor.rise)+delta,1.0/1024))

static func ready_to_fight(state: Dictionary, src: Dictionary, id: String) -> bool:
	var actor: Dictionary=state.actors[id]
	if actor.health<=0 or not actor.woken or not actor.present: return false
	return actor.rise>=clip_seconds(int(src.definitions[str(int(actor_row(src,id).definition))].clips.rise.frames))

## One live step for a ready actor; rotates the source attack variants per clip.
static func advance_live(state: Dictionary, src: Dictionary, id: String, delta: float, distance: float, sight: bool, protected: bool, player_health: int) -> int:
	var live: Dictionary=state.live[id]
	var before:=int(live.mode)
	var before_elapsed:=float(live.elapsed)
	var rules:=attack_rules(src,id,int(live.attack))
	var damage:=Live.advance(live,true,delta,distance,sight,protected,player_health,rules)
	if before==Live.ATTACK and (int(live.mode)!=Live.ATTACK or float(live.elapsed)<before_elapsed):
		# Clip completed (possibly re-entering a new clip in the same step).
		live.attack=posmod(int(live.attack)+1,src.definitions[str(int(actor_row(src,id).definition))].clips.attacks.size())
		live.hits=0
		return damage
	if int(live.mode)!=Live.ATTACK: return damage
	if live.hit and int(live.hits)==0: live.hits=1
	# Second source impact (selector12/13 frames6 and11) inside the same clip.
	if live.hit and rules.impacts.size()>1 and int(live.hits)==1 and float(live.elapsed)>=float(rules.impacts[1][0]):
		live.hits=2
		var remaining:=player_health-damage
		if sight and distance<=REACH and not protected and remaining>0: damage+=mini(int(rules.impacts[1][1]),remaining)
	return damage
