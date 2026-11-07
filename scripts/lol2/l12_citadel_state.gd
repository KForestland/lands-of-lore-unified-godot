extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const KEY="l12_citadel"
const PICTURE="act2:L12_CM:kenneth_picture"
const CHARM="act2:L12_CM:kenneth_charm"
const TARGET="kenneth:picture_impact"
static func initial()->Dictionary:return {"version":1,"searched":false,"armed":false,"slots":{},"baccata_seen":false,"talked":false,"movie_seen":false}
static func broken(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=7 or s.get("version")!=1:return "Invalid citadel approach."
 for k in ["searched","armed","baccata_seen","talked","movie_seen"]:
  if not s.get(k) is bool:return "Invalid citadel receipt."
 if not s.get("slots") is Dictionary:return "Invalid picture transaction."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid picture slot."
 var history:Dictionary=quests.get("act2_items",{});var collected:Array=history.get("collected",[]);var carried:Array=history.get("carried",[])
 if s.searched!=(PICTURE in collected):return "Picture search/history disagrees."
 if broken(s):
  var slot:=Kit.slot(s,TARGET)
  if not s.searched or s.armed or s.slots.size()!=1 or slot.size()!=3 or slot.occupied!="" or slot.receipts!=[TARGET] or PICTURE in carried or CHARM not in collected:return "Picture break/history disagrees."
 elif not s.slots.is_empty() or CHARM in collected or (s.searched and PICTURE not in carried) or (s.armed and not s.searched):return "Unbroken picture history disagrees."
 if s.baccata_seen and quests.get("l8_baccata",{}).get("phase",0)!=3:return "Friendly mountain Baccata requires the earned rescue."
 if s.talked and not s.baccata_seen:return "Baccata talk precedes meeting."
 if s.movie_seen and not s.talked:return "Citadel movie precedes talk."
 return ""
static func impact(s:Dictionary,inventory:Array,item:String,capacity:int=64)->Dictionary:
 if not s.searched or not s.armed or broken(s):return Kit.refuse("Ready Kenneth's picture first.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var recipe:={"target":TARGET,"accepts":[PICTURE],"output":CHARM,"retrievable":true,"repeatable":false,"forms":["human"]}
 var result:=Kit.offer(snap,recipe,item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe,TARGET)
 if not result.ok:return result
 result=Kit.retrieve(result.snapshot,recipe)
 if not result.ok:return result
 var next:=s.duplicate(true);next.slots=result.snapshot.slots;next.armed=false
 return {"ok":true,"state":next,"inventory":result.snapshot.inventory}
