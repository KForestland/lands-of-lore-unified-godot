extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const REMAINS:="act2:L10_DC:emperor_remains"
const TARGET:="statue:left_bowl"
static func initial()->Dictionary:return {"version":1,"visited":false,"slots":{}}
static func offered(s: Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func validate(s: Variant,inventory: Array=[])->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("visited") is bool or not s.get("slots") is Dictionary:return "Invalid statue bowl state."
 var snapshot:=Kit.empty_snapshot(inventory,64);snapshot.slots=s.slots
 if not Kit.validate(snapshot).is_empty():return "Invalid statue transaction."
 for id in s.slots:
  var slot: Dictionary=s.slots[id]
  if id!=TARGET or not s.visited or not slot.committed or slot.occupied!=REMAINS or slot.receipts!=["statue:remains"] or REMAINS in inventory:return "Invalid statue bowl receipt."
 return ""
static func offer(saved: Dictionary,inventory: Array,item: String)->Dictionary:
 if not saved.visited:return Kit.refuse("Enter the statue alcove first.")
 if offered(saved):return Kit.refuse("The remains have already been offered.")
 var snapshot:=Kit.empty_snapshot(inventory,64);snapshot.slots=saved.slots.duplicate(true)
 var recipe:={"target":TARGET,"accepts":[REMAINS],"output":"","retrievable":false,"repeatable":false,"forms":["human"]}
 var r:=Kit.offer(snapshot,recipe,item,{"form":"human"})
 if not r.ok:return r
 r=Kit.occupy(snapshot,r.proposal)
 if not r.ok:return r
 r=Kit.commit(r.snapshot,recipe,"statue:remains")
 if not r.ok:return r
 var next:=saved.duplicate(true);next.slots=r.snapshot.slots
 return {"ok":true,"state":next,"inventory":r.snapshot.inventory}
