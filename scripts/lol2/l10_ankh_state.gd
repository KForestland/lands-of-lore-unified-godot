extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Handlers=preload("res://scripts/lol2/item_handlers.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const FULL:="act2:L9_DR:item0"
const ANKH:="act2:L10_DC:priest_ankh"
const TRADE:="priest:ashes"
const SLAB:="emperor:slab66"
static func initial()->Dictionary:return {"version":1,"slots":{}}
static func recipe(target: String)->Dictionary:
 return {"target":target,"accepts":[FULL if target==TRADE else ANKH],"output":ANKH,"retrievable":true,"repeatable":false,"forms":["human"]}
static func committed(saved: Dictionary,target: String)->bool:return Kit.slot(saved,target).committed
static func validate(s: Variant)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("slots") is Dictionary:return "Invalid priest ankh state."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid ankh transaction."
 for target in s.slots:
  var slot: Dictionary=s.slots[target]
  if target not in [TRADE,SLAB] or not slot.committed or slot.occupied not in ["",ANKH] or slot.receipts!=[target]:return "Invalid ankh receipt."
 if committed(s,SLAB) and not committed(s,TRADE):return "Slab needs the earned priest ankh."
 return ""
static func act(saved: Dictionary,inventory: Array,target: String,item: String="",capacity: int=64)->Dictionary:
 if target not in [TRADE,SLAB]:return Kit.refuse("Unknown ankh target.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=saved.slots.duplicate(true)
 var routed:=Handlers.route(Items.definition(ANKH if not Kit.slot(snap,target).occupied.is_empty() else item),1)
 if not routed.hosted:return Kit.refuse("This item cannot be offered to the priest or slab.")
 var r: Dictionary
 if not Kit.slot(snap,target).occupied.is_empty():r=Kit.retrieve(snap,recipe(target))
 else:
  if committed(saved,target):return Kit.refuse("This exchange is already complete.")
  if target==SLAB and not committed(saved,TRADE):return Kit.refuse("Return the priest's ashes first.")
  r=Kit.offer(snap,recipe(target),item,{"form":"human"})
  if not r.ok:return r
  r=Kit.occupy(snap,r.proposal)
  if not r.ok:return r
  r=Kit.commit(r.snapshot,recipe(target),target)
 if not r.ok:return r
 return {"ok":true,"state":{"version":1,"slots":r.snapshot.slots},"inventory":r.snapshot.inventory,"item_route":routed}
