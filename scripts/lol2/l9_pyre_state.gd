extends RefCounted
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Handlers=preload("res://scripts/lol2/item_handlers.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const URN:="act2:L10_DC:priest_urn"
const FULL:="act2:L9_DR:item0"
const BODY:="world:L9_DR:prop2406"
const BODY_SLOT:="chapel:body"
const TARGET:="chapel:ashes"
const DURATION:=4.2
static func initial()->Dictionary:return {"version":1,"body":[10538.0,140.0,-12996.0],"holding":false,"phase":0,"orbs":[],"burn":0.0,"slots":{}}
static func validate(s: Variant)->String:
 if not s is Dictionary or s.size()!=7 or s.get("version")!=1 or not s.get("holding") is bool or not s.get("body") is Array or s.body.size()!=3 or not s.get("orbs") is Array or not s.get("slots") is Dictionary:return "Invalid chapel pyre state."
 var phase=s.get("phase");var burn=s.get("burn")
 if not (phase is int or phase is float) or not is_finite(float(phase)) or phase!=floorf(phase) or phase<0 or phase>3:return "Invalid pyre phase."
 if not (burn is int or burn is float) or not is_finite(float(burn)) or burn<0 or burn>DURATION:return "Invalid pyre burn clock."
 for n in s.body:
  if not (n is int or n is float) or not is_finite(float(n)):return "Invalid body position."
 if absf(s.body[0]-10800)>1500 or absf(s.body[2]+12800)>1500 or s.body[1]<100 or s.body[1]>300:return "Body is outside the chapel."
 var seen: Array=[]
 for id in s.orbs:
  if id not in ["1205","1206"] or id in seen:return "Invalid pyre orb."
  seen.append(id)
 if (phase>0 and s.holding) or (phase==0 and not s.orbs.is_empty()) or (phase<2 and burn!=0) or (phase>=2 and s.orbs.size()!=2) or (phase==3 and burn!=DURATION):return "Pyre phase and actions disagree."
 var snapshot:=Kit.empty_snapshot([],64);snapshot.slots=s.slots
 if not Kit.validate(snapshot).is_empty():return "Invalid urn transaction."
 if phase>0 and not s.slots.has(BODY_SLOT):return "Missing placed-body receipt."
 for id in s.slots:
  var slot: Dictionary=s.slots[id]
  if id==BODY_SLOT:
   if phase==0 or not slot.committed or slot.occupied!=BODY or slot.receipts!=["chapel:place"]:return "Invalid placed-body receipt."
  elif id==TARGET:
   if phase!=3 or not slot.committed or slot.occupied not in ["",FULL] or slot.receipts!=["chapel:fill"]:return "Invalid filled urn receipt."
  else:return "Invalid pyre slot."
 return ""
static func recipe()->Dictionary:return {"target":TARGET,"accepts":[URN],"output":FULL,"retrievable":true,"repeatable":false,"forms":["human"]}
static func act(saved: Dictionary,inventory: Array,action: String,item: String="",capacity: int=64)->Dictionary:
 if saved.phase!=3:return Kit.refuse("The body must be cremated first.")
 var routed:=Handlers.route(Items.definition(item if action=="insert" else FULL),1)
 if not routed.hosted:return Kit.refuse("This item cannot fill or retrieve the urn.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=saved.slots.duplicate(true)
 var result: Dictionary
 if action=="insert":
  if Kit.slot(snap,TARGET).committed:return Kit.refuse("The ashes have already filled the urn.")
  result=Kit.offer(snap,recipe(),item,{"form":"human"})
  if not result.ok:return result
  result=Kit.occupy(snap,result.proposal)
  if not result.ok:return result
  result=Kit.commit(result.snapshot,recipe(),"chapel:fill")
 elif action=="retrieve":result=Kit.retrieve(snap,recipe())
 else:return Kit.refuse("Unknown urn action.")
 if not result.ok:return result
 var next:=saved.duplicate(true);next.slots=result.snapshot.slots
 return {"ok":true,"state":next,"inventory":result.snapshot.inventory,"item_route":routed}

static func place_body(saved: Dictionary,at: Array)->Dictionary:
 if saved.phase!=0 or not saved.holding:return Kit.refuse("The body is not being dragged.")
 # The source prop is a world token, never injected into the player's item inventory.
 var snap:=Kit.empty_snapshot([BODY],1);snap.slots=saved.slots.duplicate(true)
 var recipe:={"target":BODY_SLOT,"accepts":[BODY],"output":"","retrievable":false,"repeatable":false,"forms":["human"]}
 var result:=Kit.offer(snap,recipe,BODY,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe,"chapel:place")
 if not result.ok:return result
 var next:=saved.duplicate(true);next.phase=1;next.holding=false;next.body=at.duplicate();next.slots=result.snapshot.slots
 return {"ok":true,"state":next}
