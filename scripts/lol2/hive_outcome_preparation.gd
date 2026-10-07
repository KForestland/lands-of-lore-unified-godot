extends RefCounted
## A7544 preparation using resolved sectors and stable group member IDs.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Stats = preload("res://scripts/lol2/hive_attack_runtime.gd")
const World = preload("res://scripts/lol2/hive_outcome_world.gd")
const Group = preload("res://scripts/lol2/hive_outcome_group.gd")

static func validate_actor(actor: Variant) -> String:
	if not actor is Dictionary: return "Invalid outcome preparation actor."
	for field in ["a8","b4","a0"]:
		if not Numbers._integer(actor.get(field),255): return "Invalid preparation field: "+field
	if not Numbers._integer(actor.get("id"),4294967295) or not Numbers._integer(actor.get("word84"),65535): return "Invalid preparation identity/counter."
	if actor.has("next_actor") and actor.next_actor!=null and not Numbers._integer(actor.next_actor,4294967295): return "Invalid next actor ID."
	var bank := Stats.apply_stat_adjustments(actor.get("stats"),{},[])
	return bank.error if bank.has("error") else ""

static func run(saved: Variant, supplied_world: Variant) -> Dictionary:
	var error := validate_actor(saved)
	if not error.is_empty(): return {"error":error}
	if not supplied_world is Dictionary: return {"error":"Invalid outcome world snapshot."}
	var state: Dictionary = saved.duplicate(true)
	for field in ["id","a8","b4","a0","word84"]: state[field]=int(state[field])
	state.stats=Stats.apply_stat_adjustments(state.stats,{},[]).stats
	for i in range(30): state.stats[i]=int(state.stats[i])
	var world: Dictionary = supplied_world.duplicate(true)
	state.b4 &= 0xf7
	state.word84=0
	# This bypass precedes all sector/group work in A7544.
	if state.a8==15: return {"state":state,"world":world,"already":true,"adjustments":[]}
	for field in ["sector","neighbors","sector_flags","peers","group"]:
		if not world.has(field): return {"error":"Missing outcome world field: "+field}
	var group: Dictionary = {}
	if world.group!=null:
		var restored := Group.restore(world.group)
		if restored.has("error"): return restored
		group=restored.group
	if state.a0!=255:
		if group.is_empty() or group.index!=state.a0: return {"error":"Outcome actor group is unavailable."}
		var member: int = group.members.find(state.id)
		if member<0 or int(group.flags[member])!=int(saved.b4): return {"error":"Outcome actor and group disagree."}
		group.flags[member]=state.b4
	var prepared := World.prepare(state.stats,state.a0,world.sector,world.neighbors,world.sector_flags,world.peers)
	if prepared.has("error"): return prepared
	state.stats=prepared.stats
	world.sector_flags=prepared.flags
	if state.a0!=255:
		var removed := Group.remove(group,state.id)
		if removed.has("error"): return removed
		world.group=removed.group
		state.a0=removed.removed.a0;state.b4=removed.removed.b4;state.next_actor=null
	elif not group.is_empty():
		world.group=group
	return {"state":state,"world":world,"already":false,"adjustments":prepared.operations}
