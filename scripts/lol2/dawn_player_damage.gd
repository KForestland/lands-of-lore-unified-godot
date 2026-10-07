extends RefCounted
## Live health boundary for spell32. Native difficulty/defense/gate snapshots
## remain supplied. Does not apply the generic provisional0.4 damage scale.
const Store=preload("res://scripts/lol2/dawn_projectile_store.gd")
const Damage=preload("res://scripts/lol2/hive_damage_preparation.gd")
const Health=preload("res://scripts/lol2/hive_player_health_adjustment.gd")
const Numbers=preload("res://scripts/lol2/dawn_cast_target.gd")
const PLAYER:=0x22574 # Stable source-player identity, not a Godot instance ID.

## Live callers bind owned progression and equipment; pure damage replay may
## still supply a complete context. Never mutate the caller's snapshot.
static func live_context(magic: Node, scalar: int, caster_heading: int, context: Dictionary) -> Dictionary:
	if magic==null or not magic.has_method("magic_state"):return {"error":"Player magic owner unavailable."}
	var saved: Variant=magic.magic_state()
	if not saved is Dictionary or not saved.get("player") is Dictionary:return {"error":"Invalid owned magic state."}
	if not Numbers.integer(saved.player.get("level"),1,30):return {"error":"Unsupported owned magic level."}
	if not Numbers.integer(scalar,0,128) or not Numbers.integer(caster_heading,0,65535):return {"error":"Unsupported owned damage stats."}
	var supplied:=context.duplicate(true)
	supplied.player_magic_level=int(saved.player.level)
	supplied.scalar=scalar
	supplied.attacker_heading=caster_heading
	return supplied

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
	return _apply(magic,store,prior,trial,context,{})

## Do not consume an explosion pass while silently losing another target’s
## request. Until other health owners are bound, reject such batches atomically.
static func explosion(magic: Node, store: RefCounted, id: int, neighbors: Array, context: Dictionary) -> Dictionary:
	if magic==null or not magic.has_method("health") or not magic.has_method("set_health") or store==null:return {"error":"Player damage owner unavailable."}
	var prior: Dictionary=store.checkpoint()
	var trial:=Store.new();var error:=trial.restore(prior)
	if not error.is_empty():return {"error":error}
	var pass_result:=trial.explosion(id,neighbors)
	if pass_result.has("error"):return pass_result
	if pass_result.requests.size()>1:return {"error":"Explosion batch requires additional target owners."}
	if pass_result.requests.is_empty():
		store.restore(trial.checkpoint())
		return {"requested":false,"loss":0}
	var event: Dictionary=pass_result.requests[0]
	if int(event.target)!=PLAYER:return {"error":"Explosion target owner unavailable."}
	return _apply(magic,store,prior,trial,context,event)

static func _apply(magic: Node, store: RefCounted, prior: Dictionary, trial: RefCounted, context: Dictionary, event: Dictionary) -> Dictionary:
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
	var damage:=Damage.resolve_dawn_spell(supplied) if event.is_empty() else Damage.resolve_dawn_explosion(event,supplied)
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
	var error: String=store.restore(trial.checkpoint())
	if not error.is_empty():return {"error":error}
	magic.set_health(int(health.current))
	return {"requested":true,"blocked":false,"loss":int(damage.loss),"health":int(health.current),"lethal":lethal,"calculation":damage,"displays":health.displays}
