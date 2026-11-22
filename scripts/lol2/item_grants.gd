extends RefCounted
## F08 shared grant contract; owners migrate only with pinned behavior fixtures.
## No node or save key. Pack ownership/names stay with the existing hosts.
const NativeTables=preload("res://scripts/lol2/item_grant_tables.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const Journal = preload("res://scripts/lol2/my_journal.gd")
const QuestResources = preload("res://scripts/lol2/quest_resource_protection.gd")

## Host-to-Catalog scope map follows actual existing save validators:
## Cave/carried_items -> cave (Cave transfer); Museum/validate_cave_transfer ->
## museum (museum_save); Hive dictionary and Jungle family (including Dark Halls,
## L8, L9, all Act2/3 maps and return) -> jungle (jungle_save/hive_save/act2_save).
## Act2 placement/special/charged ids are admitted separately by Items.valid.
## No current host's legacy save validator admits the generic "world" scope.
static func scope(host: Object) -> String:
	if host == null: return ""
	if host.has_method("carried_items"): return "cave"
	if host.has_method("validate_cave_transfer"): return "museum"
	return "jungle"

static func pack(host: Object) -> Array:
	if host == null: return []
	if host.has_method("carried_items"): return host.carried_items().duplicate()
	var hive: Variant = host.get("carried_inventory")
	if hive is Dictionary and hive.get("collected") is Array: return hive.collected
	var ordinary: Variant = host.get("carried_collected")
	return ordinary if ordinary is Array else []

static func room(host: Object, extra: int = 1) -> bool:
	return host != null and extra >= 0 and pack(host).size() + extra <= Catalog.MAX_CARRIED

static func known(host: Object, id: Variant) -> bool:
	return host != null and id is String and (Items.valid(id) or Catalog.admitted(id, scope(host)))

static func _error(reason: String) -> Dictionary:
	push_error("ItemGrants: " + reason)
	return {"ok":false,"reason":"That item action could not be completed.","internal_reason":reason,"added":false}

static func _writable(host: Object) -> bool:
	if host == null or host.has_method("carried_items"): return false
	var hive: Variant = host.get("carried_inventory")
	return (hive is Dictionary and hive.get("collected") is Array) or host.get("carried_collected") is Array

static func _options_error(host: Object, ids: Array, opts: Dictionary, cap_default: bool) -> String:
	if opts.has("owner_update"):
		var update:Variant=opts.owner_update
		if not update is Dictionary or not update.get("owner") is Node or not update.get("value") is Dictionary:return "invalid checkpoint publication"
		var owner:Node=update.owner
		if owner.get_parent()!=host or owner.get("host")!=host or not owner.get("state") is Dictionary or not owner.get_script() is GDScript:return "wrong checkpoint publication owner"
		var key:String=str(owner.get_script().get_script_constant_map().get("KEY",""))
		if key.is_empty() or opts.get("quest_changes",{})!={key:update.value}:return "checkpoint publication disagrees with proposal"
		var validation:Variant=owner.get_script().call("validate",update.value)
		if not validation is String or not validation.is_empty():return "invalid checkpoint publication state"
	if opts.has("quest_changes") and (not opts.quest_changes is Dictionary or (not host.get("quest_state") is Dictionary and not opts.has("owner_update"))):return "quest_changes needs a quest bank or checkpoint owner and dictionary"
	if bool(opts.get("sync_first", false)) and not bool(opts.get("sync", false)): return "sync_first needs sync"
	if str(opts.get("duplicate", "refuse")) not in ["refuse","skip","allow"]: return "unknown duplicate policy"
	if bool(opts.get("cap", cap_default)) and not opts.get("full_text") is String: return "capacity check needs full_text"
	var mode := str(opts.get("history", "none"))
	if mode not in ["none","act2","act2_once"]: return "unknown history policy"
	if mode != "none":
		var quests: Variant = host.get("quest_state")
		if not quests is Dictionary: return "Act2 history needs quest_state"
		var packet: Variant = quests.get("act2_items", Items.initial())
		if not packet is Dictionary or not packet.get("collected") is Array: return "invalid Act2 history packet"
		for id in ids:
			if not Items.valid(id): return "unknown Act2 history item"
	if bool(opts.get("sync", false)):
		if not host.get("carried_collected") is Array: return "Act2 sync needs Jungle-family pack"
		var quests: Variant = host.get("quest_state")
		if not quests is Dictionary: return "Act2 sync needs quest_state"
		if not quests.get("act2_items", Items.initial()) is Dictionary: return "invalid Act2 sync packet"
	if not str(opts.get("note", "")).is_empty() and not Journal.hints().has(str(opts.note)): return "unknown journal note"
	return ""

static func _effects(host: Object, ids: Array, opts: Dictionary) -> void:
	var sync := bool(opts.get("sync", false))
	var sync_first := bool(opts.get("sync_first", false))
	if sync and sync_first: Items.sync(host)
	var mode := str(opts.get("history", "none"))
	if mode != "none" and not ids.is_empty():
		# Deliberate normalization named in plan rev4: copy + initial fallback;
		# preserve always-vs-once spelling, base identities, and append order.
		var packet: Dictionary = host.quest_state.get("act2_items", Items.initial()).duplicate(true)
		for id in ids:
			var base := Items.base_id(id)
			if mode == "act2" or base not in packet.collected: packet.collected.append(base)
		host.quest_state.act2_items = packet
	if sync and not sync_first: Items.sync(host)
	var text := str(opts.get("text", ""))
	if not text.is_empty():
		if host.has_method("save_feedback"): host.save_feedback(text)
		elif host.has_method("_save_feedback"): host._save_feedback(text)
	if not str(opts.get("note", "")).is_empty(): Journal.discover(host, str(opts.note))
	if bool(opts.get("hud", false)):
		var hud: Variant = host.get("interface_hud")
		if is_instance_valid(hud): hud.refresh_equipment()

static func grant(host: Object, id: String, opts: Dictionary = {}) -> Dictionary:
	if not known(host, id): return _error("unknown item")
	if not _writable(host): return _error("host has no writable pack (Cave is derived)")
	var inventory := pack(host)
	var added := true
	if id in inventory:
		match str(opts.get("duplicate", "refuse")):
			"skip": added = false
			"refuse": return {"ok":false,"reason":"already carried","added":false}
	var error := _options_error(host, [id], opts, true)
	if not error.is_empty(): return _error(error)
	if added and bool(opts.get("cap", true)) and not room(host): return {"ok":false,"reason":str(opts.full_text),"added":false}
	if added: inventory.append(id)
	_effects(host, [id], opts)
	return {"ok":true,"reason":"","added":added}

static func check_commit(host: Object, new_pack: Array, opts: Dictionary = {}) -> Dictionary:
	if not _writable(host): return _error("host has no writable pack (Cave is derived)")
	var before := pack(host)
	var added: Array = new_pack.filter(func(id): return id not in before)
	for id in added:
		if not known(host, id): return _error("unknown item")
	var history_ids: Array = [opts.history_id] if opts.has("history_id") else added
	if opts.has("history_id") and not known(host, opts.history_id): return _error("unknown item")
	# Rev4: a transaction owner may have no capacity check today. Do not add one.
	var error := _options_error(host, history_ids, opts, false)
	if not error.is_empty(): return _error(error)
	if bool(opts.get("cap", false)) and new_pack.size() > Catalog.MAX_CARRIED: return {"ok":false,"reason":str(opts.full_text),"added":false}
	var changes:Dictionary=opts.get("quest_changes",{})
	var refusal:=QuestResources.host_refusal(host,before,new_pack,changes)
	if not refusal.is_empty():
		return {"ok":false,"reason":refusal,"added":false}
	return {"ok":true,"reason":"","added":not added.is_empty(),"history_ids":history_ids}

static func commit(host: Object, new_pack: Array, opts: Dictionary = {}) -> Dictionary:
	var admitted:=check_commit(host,new_pack,opts)
	if not admitted.ok:return admitted
	var before:=pack(host)
	var changes:Dictionary=opts.get("quest_changes",{})
	if bool(opts.get("preserve_alias", false)):
		# The Hive flute historically assigns into the live array; ordinary
		# way-C transactions retain their replacement behavior by default.
		if before != new_pack: before.assign(new_pack)
	elif host.get("carried_inventory") is Dictionary:
		# Way C replaces the array (player_item_controller.use); way B's rule
		# callers keep using the live pack accessor and their existing assign.
		host.carried_inventory.collected = new_pack
	else:
		host.carried_collected = new_pack
	# No await or callback between admission, pack and quest-state ownership.
	# Sync/text/Journal/HUD effects happen only after both are committed.
	if opts.has("owner_update"):
		var update:Dictionary=opts.owner_update
		update.owner.set("state",update.value)
	elif not changes.is_empty():host.quest_state.merge(changes,true)
	var effects_owner:Variant=host.get("item_effects")
	if is_instance_valid(effects_owner) and effects_owner.has_method("prune_accessories"):effects_owner.prune_accessories(new_pack)
	# History is per added id; shared feedback/Journal/HUD occur once per commit,
	# like the existing transaction owners' single feedback/refresh call.
	_effects(host, admitted.history_ids, opts)
	return {"ok":true,"reason":"","added":admitted.added}

static func transition(host:Object,new_pack:Array,changes:Dictionary,opts:Dictionary={})->Dictionary:
	var options:=opts.duplicate();options.quest_changes=changes
	return commit(host,new_pack,options)

## Checkpoint-owned Act1 state has no shared quest dictionary. Publish the
## actual owner's validated packet with the pack before any feedback/effects.
static func owner_transition(host:Object,new_pack:Array,owner:Node,next_state:Dictionary,opts:Dictionary={})->Dictionary:
	if not is_instance_valid(owner) or owner.get_parent()!=host or owner.get("host")!=host or not owner.get("state") is Dictionary:return _error("wrong checkpoint owner")
	var key:String=str(owner.get_script().get_script_constant_map().get("KEY",""))
	if key.is_empty():return _error("checkpoint owner lacks key")
	var validation:Variant=owner.get_script().call("validate",next_state)
	if not validation is String or not validation.is_empty():return _error("invalid checkpoint owner state")
	var options:=opts.duplicate();options.quest_changes={key:next_state}
	options.owner_update={"owner":owner,"value":next_state}
	return commit(host,new_pack,options)

## Only a committed VM item effect reaches this bridge. Unknown/default/owner
## policies remain log-only; no meaning is inferred from the argument byte.
static func native(host:Object, source:Dictionary)->Dictionary:
	if host==null:return {"ok":false,"reason":"missing native item host","added":false}
	var area:=str(host.get("area_id"))
	if source.get("area","")!=area:return {"ok":false,"reason":"native area mismatch","added":false}
	var offset:=int(source.get("file_offset",-1));var row:=NativeTables.command(area,offset)
	if row.is_empty():return {"ok":false,"reason":"unlisted native item source","added":false}
	if row.get("action","") in ["log","owner"]:return {"ok":true,"reason":str(row.action),"added":false}
	if row.get("action","")!="grant":return {"ok":false,"reason":"unknown native policy","added":false}
	if not bool(source.get("opcode3_item_grant",false)) or int(source.get("global_223d4",-1))!=0:return {"ok":false,"reason":"native admission missing","added":false}
	for key:String in ["identity","arg","group","stream"]:
		if int(source.get(key,-1))!=int(row.get(key,-2)):return {"ok":false,"reason":"native command mismatch","added":false}
	if int(row.get("target",-1))!=0:return {"ok":false,"reason":"native target is not the player","added":false}
	var caller:=false
	for entry:Dictionary in row.get("callers",[]):
		if entry.object==source.get("object","") and int(entry.event)==int(source.get("event",-1)):caller=true;break
	if not caller:return {"ok":false,"reason":"native caller mismatch","added":false}
	var rivals:Array=row.get("same_definition",[]);var blocked:Array=row.get("blocked_by",[])
	if not rivals.is_empty() and str(row.get("same_definition_evidence","")).is_empty():
		for rival:String in rivals:
			var covered:=false
			for id:String in blocked:
				if Items.base_id(id)==Items.base_id(rival):covered=true;break
			if not covered:return {"ok":false,"reason":"unsafe native duplicate policy","added":false}
	if not row.get("full_text") is String:return {"ok":false,"reason":"native capacity text missing","added":false}
	var id:=NativeTables.id_of(area,offset)
	var packet:Dictionary=host.quest_state.get("act2_items",Items.initial())
	if Items.base_id(id) in packet.collected:return {"ok":false,"reason":"native item already collected","added":false}
	for rival:String in blocked:
		if Items.base_id(rival) in packet.collected:return {"ok":false,"reason":"native rival already collected","added":false}
	return grant(host,id,{"history":"act2_once","sync":true,"full_text":row.full_text,"text":str(row.get("text","")),"note":str(row.get("note",""))})
