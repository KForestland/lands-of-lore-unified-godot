extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY:="l8_larkhon"
const VAPORS:="act2:L8_SJ:larkhon_vapors"
const LEAF:="mix:leaf"
const SERUM:="mix:serum"
const CHEST:="larkhon:chest"
const SLEEP:=60.0
# Owner-reported stuck point 2026-11-03 (DEVIATIONS 0306): state-matched guidance at the guardian, shown only for what
# Luther has already earned (hintbook ch.8 "Savage Jungle": shaman potion, combine with the leaf, activate, upper chest).
const JOURNAL_HINTS:=[
 {"when":"larkhon_must_sleep","flag":"","hint":"The Larkhon guards the way to the Claw Mountains. I cannot get past it awake; something must put it to sleep.","enhanced_guard":"same note and near-guardian line in both editions"},
 {"when":"larkhon_join_tribe","flag":"","hint":"Only the shaman can make the Larkhon sleep, and he helps his tribe alone. Show Daniel's blade to the village guard first.","enhanced_guard":"same note and near-guardian line in both editions (owner r14 playtest 2026-11-05)"},
 {"when":"larkhon_ask_shaman","flag":"l8_shaman_trade","hint":"The Larkhon will not let me pass. The tribe's shaman knows the jungle's herbs; he may help me for another Silverleaf.","enhanced_guard":"same note and near-guardian line in both editions"},
 {"when":"larkhon_serum_needs_leaf","flag":"l8_larkhon","hint":"Amaranth Serum does nothing alone. Mixed with a Silverleaf, it might put the Larkhon to sleep.","enhanced_guard":"same note and near-guardian line in both editions"},
 {"when":"larkhon_vapors_unactivated","flag":"l8_larkhon","hint":"The Larkhon Vapors must be activated first, then used on the creature's upper chest.","enhanced_guard":"same note and near-guardian line in both editions"}]
static func initial()->Dictionary:return {"version":1,"slots":{},"leaf":"","serum":"","active":false,"sleep":0.0}
static func mixed(s:Dictionary)->bool:return Kit.slot(s,SERUM).committed
static func used(s:Dictionary)->bool:return Kit.slot(s,CHEST).committed
static func recipe(target:String,item:String,output:String="",retrieve:bool=false)->Dictionary:
 return {"target":target,"accepts":[item],"output":output,"retrievable":retrieve,"repeatable":false,"forms":["human"]}
static func deposit(snap:Dictionary,r:Dictionary,item:String)->Dictionary:
 var r1:=Kit.offer(snap,r,item,{"form":"human"})
 if not r1.ok:return r1
 var r2:=Kit.occupy(snap,r1.proposal)
 if not r2.ok:return r2
 return Kit.commit(r2.snapshot,r,r.target)
static func mix(s:Dictionary,inventory:Array,leaf:String,serum:String,capacity:int=64)->Dictionary:
 if mixed(s):return Kit.refuse("You have already prepared these vapors.")
 if Items.definition(leaf)!=117 or Items.definition(serum)!=119:return Kit.refuse("Mix Silverleaf with Amaranth Serum.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=s.slots.duplicate(true)
 var a:=deposit(snap,recipe(LEAF,leaf),leaf)
 if not a.ok:return a
 var r:=recipe(SERUM,serum,VAPORS,true)
 var b:=deposit(a.snapshot,r,serum)
 if not b.ok:return b
 var c:=Kit.retrieve(b.snapshot,r)
 if not c.ok:return c
 var next:=s.duplicate(true);next.slots=c.snapshot.slots;next.leaf=leaf;next.serum=serum
 return {"ok":true,"state":next,"inventory":c.snapshot.inventory}
static func apply(s:Dictionary,inventory:Array,item:String)->Dictionary:
 if not mixed(s) or not s.active or used(s):return Kit.refuse("Activate the Larkhon Vapors first.")
 var snap:=Kit.empty_snapshot(inventory,64);snap.slots=s.slots.duplicate(true)
 var result:=deposit(snap,recipe(CHEST,VAPORS),item)
 if not result.ok:return result
 var next:=s.duplicate(true);next.slots=result.snapshot.slots;next.active=false;next.sleep=SLEEP
 return {"ok":true,"state":next,"inventory":result.snapshot.inventory}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=6 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("leaf") is String or not s.get("serum") is String or not s.get("active") is bool:return "Invalid Larkhon state."
 if not (s.get("sleep") is float or s.get("sleep") is int) or not is_finite(float(s.sleep)) or s.sleep<0 or s.sleep>SLEEP:return "Invalid Larkhon sleep clock."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid Larkhon transactions."
 var history:Dictionary=quests.get("act2_items",{});var carried:Array=history.get("carried",[]);var collected:Array=history.get("collected",[])
 if not mixed(s):
  if not s.slots.is_empty() or s.leaf!="" or s.serum!="" or s.active or s.sleep!=0 or VAPORS in collected:return "Unmixed Larkhon state changed."
  return ""
 if Items.definition(s.leaf)!=117 or Items.definition(s.serum)!=119 or s.leaf in carried or s.serum in carried or s.leaf not in collected or s.serum not in collected or VAPORS not in collected:return "Larkhon recipe history disagrees."
 if s.slots.size()!=(3 if used(s) else 2):return "Unexpected Larkhon slot."
 for target in [LEAF,SERUM]:
  var slot:Dictionary=Kit.slot(s,target)
  if slot.size()!=3 or not slot.committed or slot.receipts!=[target] or slot.occupied!=(s.leaf if target==LEAF else ""):return "Invalid mixing receipt."
 if used(s):
  var slot:Dictionary=Kit.slot(s,CHEST)
  if slot.size()!=3 or slot.occupied!=VAPORS or slot.receipts!=[CHEST] or VAPORS in carried or s.active:return "Invalid Larkhon offering receipt."
 elif VAPORS not in carried or s.sleep!=0:return "Unused vapors missing or premature sleep."
 return ""
