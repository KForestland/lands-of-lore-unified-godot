extends RefCounted
## Book-led shore exchange; original actor20 offer13602 / prop102 reward4340.
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const KEY:="l8_dawn"
const BRACERS:="act2:L9_DR:item55"
const TOKEN:="act2:L8_SJ:dawn_control_token"
const TARGET:="dawn:bracers"
static func initial()->Dictionary:return {"version":1,"slots":{}}
static func completed(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func recipe()->Dictionary:return {"target":TARGET,"accepts":[BRACERS],"output":TOKEN,"retrievable":true,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("slots") is Dictionary:return "Invalid Dawn exchange."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid Dawn transaction."
 for target in s.slots:
  var slot:Dictionary=s.slots[target]
  if target!=TARGET or slot.size()!=3 or not slot.committed or slot.occupied!="" or slot.receipts!=[TARGET]:return "Invalid Dawn receipt."
 var items:Dictionary=quests.get("act2_items",{})
 if completed(s)!=(TOKEN in items.get("collected",[])):return "Dawn reward history disagrees."
 if completed(s) and (not quests.get("l8_shore",{}).get("arrived",false) or BRACERS in items.get("carried",[])):return "Dawn exchange requires shore arrival and surrendered bracers."
 return ""
static func exchange(s:Dictionary,inventory:Array,item:String,capacity:int=64)->Dictionary:
 if completed(s) or TOKEN in inventory:return Kit.refuse("Dawn has already accepted the bracers.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var result:=Kit.offer(snap,recipe(),item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(),TARGET)
 if not result.ok:return result
 result=Kit.retrieve(result.snapshot,recipe())
 if not result.ok:return result
 return {"ok":true,"state":{"version":1,"slots":result.snapshot.slots},"inventory":result.snapshot.inventory}
