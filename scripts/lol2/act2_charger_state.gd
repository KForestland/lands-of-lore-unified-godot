extends RefCounted
## Book recipe, modern transaction host. No second inventory is persisted here.
const Kit = preload("res://scripts/lol2/mechanism_transaction.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const TARGETS := {"L10:yellow":"yellow", "L10:blue":"blue", "L9:white":"white"}
static func initial() -> Dictionary: return {"version":1,"slots":{}}
static func snapshot(state: Dictionary, inventory: Array) -> Dictionary:
 return {"version":1,"inventory":inventory.duplicate(),"capacity":64,"slots":state.slots.duplicate(true)}
static func validate(state: Variant, inventory: Array = []) -> String:
 if not state is Dictionary or state.size()!=2 or state.get("version")!=1 or not state.get("slots") is Dictionary: return "Invalid charger state."
 var error := Kit.validate(snapshot(state,inventory))
 if not error.is_empty(): return error
 var held: Array = []
 for id in inventory:
  if not id is String or Items.base_id(id) in held: return "Duplicate inventory instance."
  held.append(Items.base_id(id))
 for target in state.slots:
  if not TARGETS.has(target): return "Unknown charger."
  var entry: Dictionary = state.slots[target]
  var occupied: String = entry.occupied
  if not occupied.is_empty():
   if not occupied.ends_with(":charged:"+TARGETS[target]) or not Items.valid(occupied) or not entry.committed: return "Invalid charged globe."
   if Items.base_id(occupied) in held: return "Globe exists both in slot and inventory."
   held.append(Items.base_id(occupied))
  elif entry.committed: return "Empty charger cannot remain committed."
  var seen := {}
  for receipt in entry.receipts:
   if not receipt is String or seen.has(receipt): return "Invalid charger receipt."
   seen[receipt] = true
 return ""
static func act(state: Dictionary, inventory: Array, target: String, action: String, item: String = "") -> Dictionary:
 var error := validate(state,inventory)
 if not error.is_empty(): return Kit.refuse(error)
 if not TARGETS.has(target): return Kit.refuse("Unknown charger.")
 var data := snapshot(state,inventory)
 var recipe := {"target":target,"accepts":inventory.filter(func(id): return Items.definition(id)==98),"output":"{item}:charged:"+TARGETS[target],"retrievable":true,"repeatable":true}
 var result: Dictionary
 var routed: Dictionary={}
 if action=="insert":
  routed=preload("res://scripts/lol2/item_handlers.gd").route(Items.definition(item),1)
  if not routed.hosted:return Kit.refuse("The charger requires an empty glass globe.")
  result = Kit.offer(data,recipe,item)
  if not result.ok: return result
  result = Kit.occupy(data,result.proposal)
  if not result.ok: return result
  result = Kit.commit(result.snapshot,recipe,target+":"+item)
 elif action=="retrieve": result = Kit.retrieve(data,recipe)
 else: return Kit.refuse("Unknown charger action.")
 if not result.ok: return result
 return {"ok":true,"state":{"version":1,"slots":result.snapshot.slots},"inventory":result.snapshot.inventory,"item_route":routed}

static func transport_error(quests: Dictionary) -> String:
 var packet: Variant = quests.get("act2_items",Items.initial())
 var packet_error := Items.validate(packet)
 if not packet_error.is_empty(): return packet_error
 var inventory: Array = packet.carried
 var state: Variant = quests.get("act2_chargers",initial())
 var error := validate(state,inventory)
 if not error.is_empty(): return error
 var collected: Array = quests.get("act2_items",{}).get("collected",[])
 for target in state.slots:
  var item: String = state.slots[target].occupied
  if not item.is_empty() and Items.base_id(item) not in collected: return "Occupied globe lacks earned collection history."
 return ""
