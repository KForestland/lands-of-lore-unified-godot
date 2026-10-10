extends RefCounted
## Stable-ID representation of the active/inactive lists used by command activation.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Commands = preload("res://scripts/lol2/hive_executioner_command_queue.gd")
static func restore(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or int(saved.version)!=1: return {"error":"Invalid Hive actor registry."}
	var state := {"version":1,"active":[],"inactive":[]}
	var seen := {}
	for field in ["active","inactive"]:
		if not saved.get(field) is Array: return {"error":"Missing actor registry list."}
		for value in saved[field]:
			if not Numbers._integer(value,4294967295): return {"error":"Invalid registry actor ID."}
			var id := int(value)
			if seen.has(id): return {"error":"Duplicate registry actor ID."}
			seen[id]=true;state[field].append(id)
	return {"checkpoint":state}
static func activate_executioner(saved: Variant, actor: Variant) -> Dictionary:
	var restored := restore(saved)
	if restored.has("error"): return restored
	var result := Commands.activation(actor)
	if result.has("error"): return result
	var state: Dictionary = restored.checkpoint
	if not result.accepted: return {"checkpoint":state,"state":result.state,"accepted":false}
	if result.register:
		if 36 in state.active: return {"error":"Executioner registration flags disagree with active list."}
		state.inactive.erase(36);state.active.push_front(36)
	elif 36 not in state.active:
		return {"error":"Registered executioner is missing from active list."}
	return {"checkpoint":state,"state":result.state,"accepted":true}

static func apply_material_refresh(saved: Variant, actor: Variant, actor_id: Variant, marked: Variant) -> Dictionary:
	# B70B7 after height/region admission, for non-player registry actors.
	var restored := restore(saved)
	if restored.has("error"): return restored
	if not actor is Dictionary or not Numbers._integer(actor_id,4294967295) or not marked is bool: return {"error":"Invalid material refresh actor."}
	for field in ["flags16","flags17"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid material refresh flags."}
	var state: Dictionary = restored.checkpoint
	var updated: Dictionary = actor.duplicate(true)
	updated.flags16=int(updated.flags16);updated.flags17=int(updated.flags17)
	var id := int(actor_id)
	var registered := (int(updated.flags17)&32)!=0
	if registered!=(id in state.active): return {"error":"Material refresh registration flags disagree with active list."}
	if marked:
		updated.flags16|=1
		if not registered:
			state.inactive.erase(id)
			state.active.append(id)
			updated.flags17|=32
	return {"checkpoint":state,"state":updated}

static func refresh_material_region(saved: Variant, actor: Variant, actor_id: Variant, context: Variant) -> Dictionary:
	# B6D98 zero delta, floor-side refresh. Source region/floor providers are explicit.
	if not actor is Dictionary or not context is Dictionary: return {"error":"Invalid material refresh context."}
	for field in ["flags14","flags15"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Missing material refresh mode flags."}
	var marked := (int(actor.flags15)&32)!=0
	if (int(actor.flags14)&3)==2:
		if not context.get("same_region") is bool: return {"error":"Missing material refresh region comparison."}
		if context.same_region:
			var spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
			if not spatial._signed(context.get("actor_z")) or not spatial._signed(context.get("floor_height")): return {"error":"Missing material refresh heights."}
			marked=marked or int(context.floor_height)>=int(context.actor_z)
	return apply_material_refresh(saved,actor,actor_id,marked)
