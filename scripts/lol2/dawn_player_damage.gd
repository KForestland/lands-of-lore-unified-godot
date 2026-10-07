extends RefCounted
## Live health boundary for spell32. Native difficulty/defense/gate snapshots
## remain supplied. Does not apply the generic provisional0.4 damage scale.
const Store=preload("res://scripts/lol2/dawn_projectile_store.gd")
const Damage=preload("res://scripts/lol2/hive_damage_preparation.gd")
const Health=preload("res://scripts/lol2/hive_player_health_adjustment.gd")
const Numbers=preload("res://scripts/lol2/dawn_cast_target.gd")
const PLAYER:=0x22574 # Stable source-player identity, not a Godot instance ID.

## Validate/calculate on a private checkpoint before touching either owner.
static func direct(magic: Node, store: RefCounted, id: int, collision_heading: int, context: Dictionary) -> Dictionary:
	if magic==null or not magic.has_method("health") or not magic.has_method("set_health") or store==null:return {"error":"Player damage owner unavailable."}
	var prior: Dictionary=store.checkpoint()
	var trial:=Store.new();var error:=trial.restore(prior)
	if not error.is_empty():return {"error":error}
	var impact:=trial.impact(id,0,PLAYER,collision_heading)
	if impact.has("error"):return impact
	if not impact.request:
		store.restore(trial.checkpoint())
		return {"requested":false,"loss":0}
	var supplied:=context.duplicate(true)
	var current: int=magic.health()
	if context.has("current") and context.current!=current:return {"error":"Stale player health snapshot."}
	supplied.current=current
	for field in ["global223d4","flags228"]:
		if not Numbers.integer(supplied.get(field),0,255):return {"error":"Missing player entry gate: "+field}
	if int(supplied.global223d4)!=0:
		store.restore(trial.checkpoint())
		return {"requested":true,"blocked":true,"loss":0}
	if (int(supplied.flags228)&8)!=0:return {"error":"Player zero-state continuation unavailable."}
	for effect in trial.checkpoint().effects:
		if effect.id==id:supplied.attacker_heading=int(effect.contact.heading)
	var damage:=Damage.resolve_dawn_spell(supplied)
	if damage.has("error"):return damage
	# The modern host observes health0 for its existing death flow. Keep original
	# virtual84 ordering; do not claim the native lethal continuation is executed.
	var lethal: bool=int(damage.loss)>0 and int(damage.remaining)==0
	var surviving:=damage.duplicate(true)
	if lethal:surviving.loss=0;surviving.remaining=current
	var health:=Health.finalize(supplied,surviving)
	if health.has("error"):return health
	if lethal:health.current=0
	# No callbacks occurred during planning. Guard a future reentrant owner too.
	if store.checkpoint()!=prior or magic.health()!=current:return {"error":"Damage owners changed during preparation."}
	error=store.restore(trial.checkpoint())
	if not error.is_empty():return {"error":error}
	magic.set_health(int(health.current))
	return {"requested":true,"blocked":false,"loss":int(damage.loss),"health":int(health.current),"lethal":lethal,"calculation":damage,"displays":health.displays}
