extends RefCounted
## AB0F8 decision scans, separated at every externally applied action.
## Caller resolves current actor/region state and applies decision/cleanup effects.
const Clock = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func begin(capacity: int, cursors: Array) -> Dictionary:
	if capacity < 0 or capacity > 65535 or cursors.size() != 2: return {"error":"Invalid AI scan configuration."}
	for cursor in cursors:
		if cursor is bool or not (cursor is int or cursor is float): return {"error":"Invalid AI cursor."}
		if cursor != -1 and not Clock._integer(cursor,maxi(0,capacity-1)): return {"error":"Invalid AI cursor."}
	return {"state":{"version":1,"capacity":capacity,"cursors":[int(cursors[0]),int(cursors[1])],"pass":2 if capacity == 0 or cursors[0] == -1 else 0,"scanned":0,"disabled":cursors[0] == -1}}

static func validate(state: Variant) -> String:
	if not state is Dictionary or not Clock._integer(state.get("version"),1) or state.version != 1: return "Invalid AI scan checkpoint."
	if not Clock._integer(state.get("capacity"),65535) or not state.get("cursors") is Array: return "Invalid AI scan capacity/cursors."
	if begin(int(state.capacity),state.cursors).has("error"): return "Invalid AI scan cursors."
	if not Clock._integer(state.get("pass"),2) or not Clock._integer(state.get("scanned"),int(state.capacity)) or not state.get("disabled") is bool: return "Invalid AI scan progress."
	if state.disabled != (state.cursors[0] == -1): return "Inconsistent AI disabled state."
	if (state.disabled or state.capacity == 0) and state.pass != 2: return "Inactive AI scan must be complete."
	return ""

static func restore(saved: Variant) -> Dictionary:
	var error := validate(saved)
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":{"version":1,"capacity":int(saved.capacity),
		"cursors":[int(saved.cursors[0]),int(saved.cursors[1])],
		"pass":int(saved.pass),"scanned":int(saved.scanned),"disabled":saved.disabled}}

static func next_action(saved: Variant, snapshot: Variant) -> Dictionary:
	var error := validate(saved)
	if not error.is_empty(): return {"error":error}
	if not snapshot is Array or snapshot.size() != saved.capacity: return {"error":"AI snapshot capacity changed."}
	# Validate everything before advancing a cursor. Each action uses a fresh snapshot.
	for row in snapshot:
		if not row is Dictionary or not row.get("allocated") is bool: return {"error":"Invalid actor allocation state."}
		if not row.allocated: continue
		if not Clock._integer(row.get("a8"),255) or not Clock._integer(row.get("b5"),255): return {"error":"Invalid actor AI bytes."}
		if not Clock._integer(row.get("actor70"),4294967295): return {"error":"Invalid actor mode context."}
		if not row.get("region_present") is bool or not Clock._integer(row.get("region_flags"),65535) or not Clock._integer(row.get("object_flags"),4294967295): return {"error":"Invalid actor region context."}
	var state: Dictionary = saved.duplicate(true)
	state.capacity = int(state.capacity);state.pass = int(state.pass);state.scanned = int(state.scanned)
	state.cursors = [int(state.cursors[0]),int(state.cursors[1])]
	while state.pass < 2:
		var pass_index: int = state.pass
		if state.scanned >= state.capacity:
			state.pass += 1;state.scanned = 0
			continue
		var index: int = (state.cursors[pass_index]+1)%state.capacity
		state.cursors[pass_index] = index
		state.scanned += 1
		var row: Dictionary = snapshot[index]
		if not row.allocated or int(row.a8) == 15: continue
		var region_active: bool = row.region_present and (int(row.region_flags)&4) != 0
		if pass_index == 0:
			if not region_active: continue
			state.pass = 1;state.scanned = 0
			var action := {"type":"decision","index":index,"pass":0}
			if (int(row.actor70)&15) == 3: action["set_b5"] = int(row.b5)|12
			return {"state":state,"action":action}
		if region_active: continue
		if not row.region_present or (int(row.object_flags)&32) != 0:
			return {"state":state,"action":{"type":"cleanup","index":index,"pass":1}}
		state.pass = 2;state.scanned = 0
		return {"state":state,"action":{"type":"decision","index":index,"pass":1}}
	return {"state":state,"action":{},"done":true}
