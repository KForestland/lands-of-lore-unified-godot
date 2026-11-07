extends RefCounted
## Grok l10_tomb_doors.md static joins; consume/open is the lead's modern adapter.
const Kit = preload("res://scripts/lol2/mechanism_transaction.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const ROWS := {"87":[88,99],"91":[92,99],"95":[96,99],"99":[100,99],"105":[106,99],"108":[107,99],"109":[112,100],"152":[153,99],"154":[155,101],"156":[157,101],"158":[159,99],"161":[162,99],"164":[163,99]}
static func initial() -> Dictionary: return {"version":1,"slots":{}}
static func doors() -> Array:
 var out: Array=[]
 for row in ROWS.values(): out.append(row[0])
 return out
static func validate(state: Variant, quests: Dictionary) -> String:
 if not state is Dictionary or state.size()!=2 or state.get("version")!=1 or not state.get("slots") is Dictionary: return "Invalid tomb state."
 var packet: Variant=quests.get("act2_items",Items.initial())
 var packet_error:=Items.validate(packet)
 if not packet_error.is_empty():return packet_error
 var inventory: Array=packet.carried
 var error:=Kit.validate({"version":1,"inventory":inventory,"capacity":64,"slots":state.slots})
 if not error.is_empty(): return error
 var held: Array=[]
 for id in inventory: held.append(Items.base_id(id))
 for entry in quests.get("act2_chargers",{}).get("slots",{}).values():
  if not entry.occupied.is_empty(): held.append(Items.base_id(entry.occupied))
 for target in state.slots:
  if not ROWS.has(target): return "Unknown tomb receptacle."
  var entry: Dictionary=state.slots[target]
  var base:=Items.base_id(entry.occupied)
  if not entry.committed or Items.definition(entry.occupied)!=ROWS[target][1] or entry.receipts!=["tomb:"+target]: return "Invalid tomb offering."
  if base in held or base not in quests.get("act2_items",{}).get("collected",[]): return "Tomb globe lacks unique earned ownership."
  held.append(base)
 return ""
static func offer(state: Dictionary, inventory: Array, target: String, item: String) -> Dictionary:
 if not ROWS.has(target): return Kit.refuse("Unknown tomb receptacle.")
 var data: Dictionary={"version":1,"inventory":inventory.duplicate(),"capacity":64,"slots":state.slots.duplicate(true)}
 var recipe: Dictionary={"target":target,"accepts":inventory.filter(func(id):return Items.definition(id)==ROWS[target][1]),"retrievable":false}
 var result:=Kit.offer(data,recipe,item)
 if not result.ok:return result
 result=Kit.occupy(data,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe,"tomb:"+target)
 if not result.ok:return result
 return {"ok":true,"state":{"version":1,"slots":result.snapshot.slots},"inventory":result.snapshot.inventory}
