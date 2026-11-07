extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY="l13_dawn_release"
const TARGET="dawn:dreamstone"
const REWARD="act2:L13_RC:dawn_bestial_disk"
static func initial()->Dictionary:return {"version":1,"slots":{},"stone":""}
static func completed(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("stone") is String:return "Invalid Dawn release."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid Dawn receptacle."
 if not completed(s):
  if not s.slots.is_empty() or s.stone!="":return "Unstarted Dawn release changed."
  return ""
 var slot:Dictionary=s.slots[TARGET];var history:Array=quests.get("act2_items",{}).get("collected",[])
 if s.slots.size()!=1 or slot.size()!=3 or slot.occupied!="" or slot.receipts!=[TARGET] or Items.definition(s.stone)!=136 or s.stone not in history or REWARD not in history:return "Dawn release receipt disagrees."
 var prison:Dictionary=quests.get("l13_dawn_prison",{})
 if not prison.get("visited",false) or not prison.get("released",false):return "Dawn reward precedes release."
 return ""
static func offer(s:Dictionary,inventory:Array,item:String,capacity:int=64)->Dictionary:
 if completed(s):return Kit.refuse("Dawn is already free.")
 if Items.definition(item)!=136:return Kit.refuse("The recess needs the Dreamstone.")
 if inventory.size()>=capacity:return Kit.refuse("Make room for Dawn's gift first.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var recipe:={"target":TARGET,"accepts":[item],"output":"{item}","retrievable":true,"repeatable":false,"forms":["human"]}
 var result:=Kit.offer(snap,recipe,item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe,TARGET)
 if not result.ok:return result
 result=Kit.retrieve(result.snapshot,recipe)
 if not result.ok:return result
 result.snapshot.inventory.append(REWARD)
 return {"ok":true,"state":{"version":1,"slots":result.snapshot.slots,"stone":item},"inventory":result.snapshot.inventory}
