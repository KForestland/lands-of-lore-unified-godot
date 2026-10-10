extends RefCounted
## Scoped actor36 hit commands. Cursor mirrors the native duplicate-scan boundary.
## Enclosing actor update and global script queues remain controller-owned.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func restore(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or int(saved.version)!=1 or not saved.get("commands") is Array:
		return {"error":"Invalid executioner command queue."}
	var commands: Array = []
	for command in saved.commands:
		if not Numbers._integer(command,13) or int(command) not in [7,13]: return {"error":"Unsupported executioner queued command."}
		commands.append(int(command))
	if not Numbers._integer(saved.get("cursor"),4294967295): return {"error":"Invalid executioner queue cursor."}
	return {"checkpoint":{"version":1,"commands":commands,"cursor":int(saved.cursor)}}
static func enqueue(saved: Variant, operations: Variant) -> Dictionary:
	var restored := restore(saved)
	if restored.has("error"): return restored
	var incoming := restore({"version":1,"commands":operations,"cursor":0})
	if incoming.has("error"): return incoming
	var state: Dictionary = restored.checkpoint
	var prior: Array = state.commands.slice(state.cursor)
	var inserted: Array = []
	# Native646EC snapshots the queue end once for the entire source group.
	for operation in incoming.checkpoint.commands:
		if operation in prior: continue
		state.commands.append(operation);inserted.append(operation)
	return {"checkpoint":state,"inserted":inserted}

static func remove(saved: Variant, index: Variant, flags16: Variant) -> Dictionary:
	var restored := restore(saved)
	if restored.has("error"): return restored
	var state: Dictionary = restored.checkpoint
	if not Numbers._integer(index,4294967295) or int(index)>=state.commands.size() or not Numbers._integer(flags16,255):
		return {"error":"Invalid executioner command removal."}
	state.commands.remove_at(int(index))
	# Actor commands preserve the duplicate cursor even past the shortened end.
	return {"checkpoint":state,"flags16":int(flags16)&251 if state.commands.is_empty() else int(flags16)}

static func next_index(count: int, previous: Variant, removed: Variant) -> Variant:
	var start := 0 if previous==null else int(previous)+int(previous!=removed)
	return start if start<count else null

static func consume(saved: Variant, actor: Variant, counter: Variant, blocked: Variant) -> Dictionary:
	var restored := restore(saved)
	if restored.has("error"): return restored
	if not actor is Dictionary or not Numbers._integer(counter,65535) or not Numbers._integer(blocked,255): return {"error":"Invalid command update context."}
	for field in ["a8","b5","flags16"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid command actor field: "+field}
	var state: Dictionary = actor.duplicate(true)
	for field in ["a8","b5","flags16"]: state[field]=int(state[field])
	var pending: Dictionary = restored.checkpoint
	var executed: Array = []
	var remaining_counter := int(counter)
	if (state.flags16&4)!=0 and int(blocked)==0:
		var index: Variant = next_index(pending.commands.size(),null,null)
		while index!=null and (state.flags16&4)!=0:
			var operation: int = pending.commands[index]
			if state.a8!=15:
				state.b5=(state.b5|12) if operation==13 else (state.b5&254)
				remaining_counter=0
			executed.append(operation)
			var removed := remove(pending,index,state.flags16)
			pending=removed.checkpoint;state.flags16=removed.flags16
			index=next_index(pending.commands.size(),index,index)
	return {"checkpoint":pending,"state":state,"counter":remaining_counter,"executed":executed}

static func activation(actor: Variant) -> Dictionary:
	if not actor is Dictionary: return {"error":"Invalid command activation actor."}
	for field in ["flags16","flags17"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid command activation field: "+field}
	var state: Dictionary = actor.duplicate(true)
	state.flags16=int(state.flags16);state.flags17=int(state.flags17)
	if (state.flags16&128)!=0: return {"state":state,"accepted":false,"register":false}
	state.flags16|=4
	var register: bool = (state.flags17&32)==0
	if register: state.flags17|=32
	# Caller stages old-list removal and active-list insertion when requested.
	return {"state":state,"accepted":true,"register":register}
