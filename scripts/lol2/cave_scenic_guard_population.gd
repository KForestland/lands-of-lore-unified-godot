extends "res://scripts/lol2/audible_creature_population.gd"
## Cave-only region969 predicate/local0 projection. Generic creature core unchanged.
func advance(delta: float) -> void:
	var captain=host.get("captain") if host!=null else null
	var held: Array=[]
	if captain!=null and not captain.fighting():
		var actor: Dictionary=state.actors["56"];held=[actor.woken,actor.rise];actor.woken=false;actor.rise=-1.0
		state.live["56"].merge({"mode":0,"elapsed":0.0,"hit":false,"hits":0},true)
		state.live["56"].erase("cooldown")
	_advance_scenic(delta)
	if not held.is_empty():state.actors["56"].woken=held[0];state.actors["56"].rise=held[1]
	if captain!=null:captain.own_region();captain.present()
func _advance_scenic(delta: float) -> void:
	var scenic=host.get("scenic_guard") if host!=null else null
	if scenic==null:
		super.advance(delta);return
	var before: bool=969 in state.regions
	var region: Dictionary={}
	for row in src.regions:
		if int(row.region)==969:region=row;break
	var spawn: Array=region.get("spawn",[])
	if int(scenic.state.local0)!=0:region.spawn=[]
	super.advance(delta)
	region.spawn=spawn
	# Use the exact floor-qualified contact already accepted by the shared owner.
	if not before and 969 in state.regions and int(scenic.state.local0)==0:
		scenic.supply_event("region969")

func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
	var before: int=int(state.actors.get(id,{}).get("health",0))
	var accepted:=super.receive_damage(id,amount,melee,effect)
	var captain=host.get("captain") if host!=null else null
	if accepted and id=="56" and captain!=null:captain.after_damage(before-int(state.actors[id].health),melee,effect)
	return accepted
