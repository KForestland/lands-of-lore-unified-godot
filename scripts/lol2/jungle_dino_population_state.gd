extends RefCounted
## Fifteen source L4_HJ DINO placements: saved health, position and live behavior.
## Source: 150HP, reward scale4, selector4 bite (frame9, native request24). Adapters:
## perception range/reach, speed, 8fps clip clocks (docs/jungle-dino-population.md).
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const SOURCE="res://scripts/lol2/jungle_dino_population_source.json"
const FPS:=8.0
const ALERT_RANGE:=240.0
const REACH:=60.0
const SPEED:=55.0
const DEATH_SECONDS:=12.0/FPS

static func source() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))

static func rules() -> Dictionary:
	var s:=source()
	return {"alert":ALERT_RANGE,"reach":REACH,"damage":Live.playable_damage(int(s.damage)),"impact":float(s.clips.bite.hit_frame)/FPS,"clip":float(s.clips.bite.frames)/FPS}

static func initial() -> Dictionary:
	var actors: Dictionary={}
	var live: Dictionary={}
	for row in source().actors:
		var id:=str(int(row.actor))
		actors[id]={"health":int(row.health),"position":row.position.map(func(n):return float(n)),"death":0.0}
		live[id]={"mode":Live.IDLE,"elapsed":0.0,"hit":false,"heading":int(row.heading)}
	return {"version":1,"actors":actors,"live":live}

static func validate(state: Variant) -> String:
	if not state is Dictionary or not Values.integer(state.get("version"),1) or state.version!=1 or not state.get("actors") is Dictionary or not state.get("live") is Dictionary: return "Invalid Jungle DINO population."
	var expected: Dictionary=initial()
	if state.actors.size()!=expected.actors.size() or state.live.size()!=expected.live.size(): return "Incomplete Jungle DINO identities."
	var r:=rules()
	for id in expected.actors:
		var actor=state.actors.get(id)
		if not actor is Dictionary or not Values.integer(actor.get("health"),150) or not Values.vector(actor.get("position"),32768): return "Invalid Jungle DINO actor."
		var death=actor.get("death")
		if not (death is int or death is float) or not is_finite(float(death)) or death<0 or death>DEATH_SECONDS: return "Invalid Jungle DINO death clock."
		if actor.health>0 and death!=0: return "Living Jungle DINO has a death clock."
		var error:=Live.validate(state.live.get(id),actor.health>0,r)
		if not error.is_empty(): return error
	return ""

static func canonical(state: Dictionary) -> Dictionary:
	var result:=state.duplicate(true)
	result.version=1
	for actor in result.actors.values():
		actor.health=int(actor.health);actor.death=float(actor.death)
		actor.position=actor.position.map(func(n):return float(n))
	for live in result.live.values():
		live.mode=int(live.mode);live.elapsed=float(live.elapsed);live.heading=int(live.heading)
		if live.has("cooldown"): live.cooldown=float(live.cooldown)
	return result

## Returns actual health loss; defeat starts the source death clip once.
static func damage(state: Dictionary, id: String, amount: int) -> int:
	if amount<=0 or not state.actors.has(id): return 0
	var actor: Dictionary=state.actors[id]
	var loss:=mini(int(actor.health),amount)
	if loss==0: return 0
	actor.health-=loss
	if actor.health==0:
		actor.death=0.0
		state.live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false},true);state.live[id].erase("cooldown")
	return loss

static func advance_death(state: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	for actor in state.actors.values():
		if actor.health==0: actor.death=minf(DEATH_SECONDS,snappedf(float(actor.death)+delta,1.0/1024))
