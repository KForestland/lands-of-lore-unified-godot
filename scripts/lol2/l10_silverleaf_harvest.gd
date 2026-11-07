extends RefCounted
const KEY:="l10_silverleaf_harvest"
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
static func initial()->Dictionary:return {"version":1,"picked":[]}
static func item_id(target:String)->String:return "act2:L10_DC:silverleaf"+target
static func valid_target(target:Variant)->bool:return target is String and target==str(int(target)) and int(target)>=159 and int(target)<=170
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("picked") is Array:return "Invalid Silverleaf harvest."
 var seen:Array=[]
 for target in s.picked:
  if not valid_target(target) or target in seen:return "Invalid Silverleaf tree identity."
  seen.append(target)
  if item_id(target) not in quests.get("act2_items",{}).get("collected",[]):return "Harvested leaf lacks reward history."
 if not seen.is_empty() and not quests.get("l10_silverleaf",{}).get("grown",false):return "Leaves cannot be picked before growth."
 for id in quests.get("act2_items",{}).get("collected",[]):
  if id.begins_with("act2:L10_DC:silverleaf") and id.trim_prefix("act2:L10_DC:silverleaf") not in seen:return "Silverleaf reward lacks tree receipt."
 return ""
static func pick(s:Dictionary,inventory:Array,items:Dictionary,target:String,capacity:int=64)->Dictionary:
 if not valid_target(target):return {"ok":false,"reason":"That is not a Silverleaf tree."}
 var id:=item_id(target)
 if target in s.picked or id in items.collected:return {"ok":false,"reason":"This tree has already been harvested."}
 if inventory.size()>=capacity:return {"ok":false,"reason":"Make room for the Silverleaf."}
 var next:=s.duplicate(true);next.picked.append(target)
 var history:=items.duplicate(true);history.collected.append(id)
 var carried:=inventory.duplicate();carried.append(id)
 return {"ok":true,"state":next,"inventory":carried,"items":history,"reason":"You pick a Silverleaf."}
