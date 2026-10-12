extends RefCounted
## Outcome sector scratch marks and ordered peer-profile adjustments.
## Caller resolves original region references into stable sector IDs.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Stats = preload("res://scripts/lol2/hive_attack_runtime.gd")

static func _flags(values: Variant) -> Dictionary:
	if not values is Array or values.size()>65536: return {"error":"Invalid outcome sectors."}
	var flags: Array = []
	for value in values:
		if not Numbers._integer(value,255): return {"error":"Invalid outcome sector flag."}
		flags.append(int(value))
	return {"flags":flags}

static func mark_sector(values: Variant, source: Variant, neighbors: Variant) -> Dictionary:
	var result := _flags(values)
	if result.has("error"): return result
	if not Numbers._integer(source,65535) or int(source)>=result.flags.size() or not neighbors is Array: return {"error":"Invalid outcome sector references."}
	var flags: Array = result.flags
	var recorded: Array = [int(source)]
	flags[int(source)]=int(flags[int(source)])|2
	for neighbor in neighbors:
		if not Numbers._integer(neighbor,65535) or int(neighbor)>=flags.size(): return {"error":"Missing outcome neighbor sector."}
		var index := int(neighbor)
		if (int(flags[index])&2)==0:
			recorded.append(index);flags[index]=int(flags[index])|2
	var cleared: Array = flags.duplicate()
	for index in recorded: cleared[index]=int(cleared[index])&0xfd
	return {"marked":flags,"recorded":recorded,"flags":cleared}

static func adjust(stats: Variant, group: Variant, peers: Variant, sector_flags: Variant) -> Dictionary:
	var result := Stats.apply_stat_adjustments(stats,{},[])
	if result.has("error"): return result
	var flags := _flags(sector_flags)
	if flags.has("error"): return flags
	if not Numbers._integer(group,255) or not peers is Array: return {"error":"Invalid outcome peer context."}
	var bank: Array = result.stats
	var operations: Array = []
	var seen := {}
	for peer in peers:
		if not peer is Dictionary or not Numbers._integer(peer.get("id"),4294967295) or not Numbers._integer(peer.get("kind"),255): return {"error":"Invalid outcome peer."}
		var id := int(peer.id)
		if seen.has(id): return {"error":"Duplicate outcome peer."}
		seen[id]=true
		if int(peer.kind)!=2: continue
		if not Numbers._integer(peer.get("group"),255): return {"error":"Invalid peer group."}
		var operation := 0
		if int(group)!=255 and int(peer.group)==int(group):
			operation=4
		else:
			if not peer.has("sector"): return {"error":"Missing peer sector."}
			if peer.sector!=null:
				if not Numbers._integer(peer.sector,65535) or int(peer.sector)>=flags.flags.size(): return {"error":"Invalid peer sector."}
				if (int(flags.flags[int(peer.sector)])&2)!=0: operation=3
		if operation==0: continue
		if not peer.get("rows") is Dictionary: return {"error":"Missing peer adjustment rows."}
		var row: Variant = peer.rows.get(str(operation))
		if not row is Array or row.size()!=30: return {"error":"Invalid peer adjustment row."}
		for i in range(30):
			if not Stats._integer(row[i],-128,127): return {"error":"Invalid peer adjustment byte."}
			bank[i]=clampi(int(bank[i])+int(row[i]),0,255)
		operations.append([id,operation])
	return {"stats":bank,"operations":operations}

static func prepare(stats: Variant, group: Variant, source: Variant, neighbors: Variant, sector_flags: Variant, peers: Variant) -> Dictionary:
	if source==null:
		var bank := Stats.apply_stat_adjustments(stats,{},[])
		if bank.has("error"): return bank
		var flags := _flags(sector_flags)
		if flags.has("error"): return flags
		return {"stats":bank.stats,"flags":flags.flags,"operations":[],"recorded":[]}
	var marked := mark_sector(sector_flags,source,neighbors)
	if marked.has("error"): return marked
	var result := adjust(stats,group,peers,marked.marked)
	if result.has("error"): return result
	return {"stats":result.stats,"flags":marked.flags,"operations":result.operations,"recorded":marked.recorded}

static func restore_checkpoint(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or int(saved.version)!=1:
		return {"error":"Invalid outcome world checkpoint."}
	var flags := _flags(saved.get("sector_flags"))
	if flags.has("error"): return flags
	if not saved.has("group"): return {"error":"Missing outcome group checkpoint."}
	var group: Variant = null
	if saved.group!=null:
		var restored := preload("res://scripts/lol2/hive_outcome_group.gd").restore(saved.group)
		if restored.has("error"): return restored
		group=restored.group
	return {"checkpoint":{"version":1,"sector_flags":flags.flags,"group":group}}
