extends RefCounted
## Global optional marker selector. This state belongs to the area/controller,
## not to each actor. The caller owns command scheduling and bank loading.
const Validation = preload("res://scripts/lol2/hive_player_conditions.gd")

static func checkpoint(bank: Variant, actor_marker: Variant, selected: Variant, counter: Variant) -> Dictionary:
	var records := resolve_geometry(bank,actor_marker,selected)
	if records.has("error"): return records
	if not Validation._integer(counter,0,65535): return {"error":"Invalid actor marker counter."}
	return {"checkpoint":{"version":1,"bank_sha256":_bank_hash(bank),
		"actor_marker":int(actor_marker),"selected":null if selected==null else int(selected),"counter":int(counter)}}

static func restore(bank: Variant, saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Validation._integer(saved.get("version"),1,1):
		return {"error":"Unsupported marker checkpoint."}
	# Missing selected is not a saved null selector; never fill constructor
	# defaults into an incomplete or foreign-area checkpoint.
	for field in ["bank_sha256","actor_marker","selected","counter"]:
		if not saved.has(field): return {"error":"Incomplete marker checkpoint."}
	var result := checkpoint(bank,saved.actor_marker,saved.selected,saved.counter)
	if result.has("error"): return result
	if saved.bank_sha256 != result.checkpoint.bank_sha256:
		return {"error":"Marker checkpoint belongs to a different bank."}
	return result

static func apply_command(bank: Variant, saved: Variant, index: Variant, actor_state: Variant) -> Dictionary:
	var restored := restore(bank,saved)
	if restored.has("error"): return restored
	var current: Dictionary = restored.checkpoint
	var change := select_marker(current.selected,index,actor_state,current.counter)
	if change.has("error"): return change
	var result := checkpoint(bank,current.actor_marker,change.selected,change.counter)
	if not result.has("error"): result.applied = change.applied
	return result

static func _bank_hash(bank: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bank)
	return context.finish().hex_encode()

static func initial_actor_marker(record: Variant) -> Dictionary:
	if not record is PackedByteArray or record.size() != 56: return {"error":"Invalid actor placement record."}
	return {"marker":record.decode_u16(39)}

static func load_hive_executioner() -> Dictionary:
	var data := load_hive_bank()
	if data.has("error"): return data
	var path := "res://assets/lol2/generated/hive_attack/actor_marker.json"
	if not FileAccess.file_exists(path): return {"error":"Executioner marker data is missing."}
	var source = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not source is Dictionary or source.get("version") != 1 or source.get("actor") != 36 or source.get("definition") != 1 or source.get("initial_marker") != 0:
		return {"error":"Invalid executioner marker data."}
	data.actor_marker = int(source.initial_marker)
	return data

static func load_hive_bank() -> Dictionary:
	var path := "res://assets/lol2/generated/hive_attack/marker_bank"
	if not FileAccess.file_exists(path+".bin") or not FileAccess.file_exists(path+".json"):
		return {"error":"Hive marker data is missing."}
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	if not manifest is Dictionary or manifest.get("version") != 1 or manifest.get("count") != 60:
		return {"error":"Invalid Hive marker manifest."}
	var bank := FileAccess.get_file_as_bytes(path+".bin")
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bank)
	if bank.size() != 480 or hash_context.finish().hex_encode() != manifest.get("bank_sha256"):
		return {"error":"Hive marker bank does not match its manifest."}
	return {"bank":bank,"count":60}

static func load_area_geometry(geometry: Variant) -> Dictionary:
	if not geometry is PackedByteArray or geometry.size() < 224:
		return {"error":"Invalid area geometry header."}
	var count: int = geometry.decode_u32(0xc4)
	var start: int = geometry.decode_u32(0xc8)
	var end := start+count*8
	var names_end := end+count*26
	if start < 224 or names_end > geometry.size() or names_end != geometry.decode_u32(0xdc):
		return {"error":"Invalid area marker section bounds."}
	return {"bank":geometry.slice(start,end),"count":count}

static func select_marker(previous: Variant, index: Variant, actor_state: Variant, counter: Variant) -> Dictionary:
	if previous != null and not Validation._integer(previous,0,65534): return {"error":"Invalid previous marker."}
	if not Validation._integer(index,0,65535) or not Validation._integer(actor_state,0,255) or not Validation._integer(counter,0,65535):
		return {"error":"Invalid marker command state."}
	if int(actor_state) == 15: return {"selected":previous,"counter":int(counter),"applied":false}
	return {"selected":null if int(index)==65535 else int(index),"counter":0,"applied":true}

static func resolve_geometry(bank: Variant, actor_marker: Variant, selected: Variant) -> Dictionary:
	if not bank is PackedByteArray or bank.size()%8 != 0: return {"error":"Invalid marker bank."}
	if not Validation._integer(actor_marker,0,65535): return {"error":"Invalid actor marker."}
	if selected != null and not Validation._integer(selected,0,65534): return {"error":"Invalid selected marker."}
	# Native selection is unchecked. Reject unavailable records explicitly;
	# never turn an unresolved actor marker into a false condition.
	if int(actor_marker) >= bank.size()/8 or (selected != null and int(selected) >= bank.size()/8):
		return {"error":"Marker record unavailable."}
	return {"region9":_record(bank,int(actor_marker)),"point41":null if selected==null else _record(bank,int(selected))}

static func _record(bank: PackedByteArray, index: int) -> Dictionary:
	var start := index*8
	return {"coordinates":[bank.decode_s16(start),bank.decode_s16(start+2)],"radius":int(bank[start+6])}
