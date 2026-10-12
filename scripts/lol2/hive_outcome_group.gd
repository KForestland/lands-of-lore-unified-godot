extends RefCounted
## Circular group order stored as stable actor IDs, beginning with its leader.
## Native group byte7 is preserved even when removing the final member.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func restore(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or saved.version!=1 or not Numbers._integer(saved.get("index"),254): return {"error":"Invalid actor group checkpoint."}
	if not saved.get("members") is Array or not saved.get("flags") is Array or saved.members.size()!=saved.flags.size() or saved.members.size()>255: return {"error":"Invalid actor group members."}
	if not saved.get("reserved") is Array or saved.reserved.size()!=3: return {"error":"Invalid actor group metadata."}
	var members: Array = [];var flags: Array = [];var reserved: Array = []
	var seen := {}
	for i in range(saved.members.size()):
		if not Numbers._integer(saved.members[i],4294967295) or not Numbers._integer(saved.flags[i],255): return {"error":"Invalid actor group member."}
		var id := int(saved.members[i])
		if seen.has(id): return {"error":"Duplicate actor group member."}
		seen[id]=true;members.append(id);flags.append(int(saved.flags[i]))
	for value in saved.reserved:
		if not Numbers._integer(value,255): return {"error":"Invalid actor group byte."}
		reserved.append(int(value))
	return {"group":{"version":1,"index":int(saved.index),"members":members,"flags":flags,"reserved":reserved}}

static func remove(saved: Variant, actor: Variant) -> Dictionary:
	var result := restore(saved)
	if result.has("error"): return result
	if not Numbers._integer(actor,4294967295): return {"error":"Invalid removed actor ID."}
	var group: Dictionary = result.group
	var position: int = group.members.find(int(actor))
	if position<0: return {"error":"Actor is not in this group."}
	var removed := {"a0":255,"b4":int(group.flags[position])&0xef,"next_actor":null}
	group.members.remove_at(position);group.flags.remove_at(position)
	if group.members.is_empty():
		group.reserved[0]=0;group.reserved[1]=0
	elif position==0:
		group.flags[0]=int(group.flags[0])|16
	return {"group":group,"removed":removed}
