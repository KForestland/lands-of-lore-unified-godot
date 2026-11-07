extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY="l13_exit_lock"
const TARGET="citadel:exit_lock104"
static func initial()->Dictionary:return {"version":1,"slots":{},"stone":""}
static func unlocked(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func recipe(item:String)->Dictionary:return {"target":TARGET,"accepts":[item],"output":"{item}","retrievable":true,"repeatable":false,"forms":["human"]}
static func insert(s:Dictionary,inventory:Array,item:String,capacity:int=64)->Dictionary:
 if unlocked(s):return Kit.refuse("The exit is already open.")
 if Items.definition(item)!=136:return Kit.refuse("The slot needs the Dreamstone.")
 if inventory.size()>=capacity:return Kit.refuse("Make room before using the slot.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var result:=Kit.offer(snap,recipe(item),item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(item),TARGET)
 if not result.ok:return result
 return {"ok":true,"inventory":result.snapshot.inventory,"state":{"version":1,"slots":result.snapshot.slots,"stone":item}}
static func retrieve(s:Dictionary,inventory:Array,capacity:int=64)->Dictionary:
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var result:=Kit.retrieve(snap,recipe(s.stone))
 if not result.ok:return result
 var next:=s.duplicate(true);next.slots=result.snapshot.slots
 return {"ok":true,"inventory":result.snapshot.inventory,"state":next}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("stone") is String:return "Invalid Citadel exit lock."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid exit-slot transaction."
 if not unlocked(s):return "" if s==initial() else "Uncommitted exit slot changed."
 var slot:Dictionary=s.slots[TARGET]
 if s.slots.size()!=1 or slot.size()!=3 or slot.receipts!=[TARGET] or slot.occupied not in ["",s.stone] or Items.definition(s.stone)!=136 or s.stone not in quests.get("act2_items",{}).get("collected",[]):return "Invalid exit-slot receipt."
 return ""
