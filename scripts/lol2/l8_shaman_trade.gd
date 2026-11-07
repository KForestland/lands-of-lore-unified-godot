extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Tribe=preload("res://scripts/lol2/l8_tribe_state.gd")
const KEY:="l8_shaman_trade"
const TARGET:="shaman:silverleaf"
const SERUM:="act2:L8_SJ:shaman_amaranth"
static func initial()->Dictionary:return {"version":1,"slots":{},"leaf":""}
static func completed(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("leaf") is String:return "Invalid shaman trade."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid shaman transaction."
 var items:Dictionary=quests.get("act2_items",{})
 if not completed(s):
  if not s.slots.is_empty() or s.leaf!="" or SERUM in items.get("collected",[]):return "Unstarted shaman trade changed."
  return ""
 var slot:Dictionary=s.slots[TARGET]
 if s.slots.size()!=1 or slot.size()!=3 or slot.occupied!="" or slot.receipts!=[TARGET]:return "Invalid shaman receipt."
 if Items.definition(s.leaf)!=117 or s.leaf in items.get("carried",[]) or s.leaf not in items.get("collected",[]) or SERUM not in items.get("collected",[]):return "Shaman offering/reward history disagrees."
 if not Tribe.member(quests.get(Tribe.KEY,{})) or s.leaf==Kit.slot(quests.get(Tribe.KEY,{}),Tribe.TARGET).occupied:return "The shaman needs another earned leaf after initiation."
 return ""
static func exchange(s:Dictionary,inventory:Array,item:String,capacity:int=64)->Dictionary:
 if completed(s) or SERUM in inventory:return Kit.refuse("The shaman has already given you the potion.")
 if Items.definition(item)!=117:return Kit.refuse("Offer another Silverleaf to the shaman.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var recipe:={"target":TARGET,"accepts":[item],"output":SERUM,"retrievable":true,"repeatable":false,"forms":["human"]}
 var result:=Kit.offer(snap,recipe,item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe,TARGET)
 if not result.ok:return result
 result=Kit.retrieve(result.snapshot,recipe)
 if not result.ok:return result
 return {"ok":true,"state":{"version":1,"slots":result.snapshot.slots,"leaf":item},"inventory":result.snapshot.inventory}
