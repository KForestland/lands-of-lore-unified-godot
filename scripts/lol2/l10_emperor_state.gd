extends RefCounted
const DeadBracers=preload("res://scripts/lol2/dead_bracers_item.gd")
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Ankh=preload("res://scripts/lol2/l10_ankh_state.gd")
const COLORS:={"125":101,"126":99,"127":100}
const REMAINS:="act2:L10_DC:emperor_remains"
const BRACERS:="act2:L9_DR:item55"
const INNER:="143"
static func initial()->Dictionary:return {"version":1,"slots":{},"remains":false}
static func count(saved: Dictionary)->int:
 var n:=0
 for id in COLORS:
  if not Kit.slot(saved,id).occupied.is_empty():n+=1
 return n
static func opened(saved: Dictionary)->bool:return count(saved)==3 and Kit.slot(saved,INNER).committed
static func validate(s: Variant,inventory: Array=[])->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("remains") is bool:return "Invalid Emperor state."
 var snap:=Kit.empty_snapshot(inventory,64);snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid Emperor transaction."
 var held: Array=inventory.map(func(id):return Items.base_id(id))
 for id in s.slots:
  var slot: Dictionary=s.slots[id]
  if id==INNER:
   if not slot.committed or slot.occupied!=Ankh.ANKH or slot.receipts!=["emperor:inner"]:return "Invalid inner ankh receipt."
  elif COLORS.has(id):
   if slot.occupied.is_empty():
    if slot.committed:return "Empty Emperor slot cannot be committed."
   elif not slot.committed or Items.definition(slot.occupied)!=COLORS[id]:return "Wrong Emperor globe."
  else:return "Unknown Emperor receptacle."
  if not slot.occupied.is_empty():
   var base:=Items.base_id(slot.occupied)
   if base in held:return "Emperor item is duplicated."
   held.append(base)
 if s.remains and not Kit.slot(s,INNER).committed:return "Remains need the inner tomb opened."
 return ""
static func act(saved: Dictionary,inventory: Array,target: String,item: String="",capacity: int=64)->Dictionary:
 var error:=validate(saved,inventory)
 if not error.is_empty():return Kit.refuse(error)
 if not COLORS.has(target) and target!=INNER:return Kit.refuse("Unknown Emperor receptacle.")
 var snap:=Kit.empty_snapshot(inventory,capacity);snap.slots=saved.slots.duplicate(true)
 var inner:=target==INNER
 if inner:
  var routed:=preload("res://scripts/lol2/item_handlers.gd").route(Items.definition(item),1)
  if not routed.hosted:return Kit.refuse("This item cannot open the inner slab.")
 var accepts: Array=[Ankh.ANKH] if inner else inventory.filter(func(id):return Items.definition(id)==COLORS[target])
 var recipe:={"target":target,"accepts":accepts,"output":"","retrievable":not inner,"repeatable":not inner,"forms":["human"]}
 var result: Dictionary
 if not Kit.slot(snap,target).occupied.is_empty():result=Kit.retrieve(snap,recipe)
 else:
  if inner and count(saved)!=3:return Kit.refuse("Place one globe of each colour first.")
  result=Kit.offer(snap,recipe,item,{"form":"human"})
  if not result.ok:return result
  result=Kit.occupy(snap,result.proposal)
  if not result.ok:return result
  var receipt: String="emperor:inner" if inner else "emperor:"+target+":"+str(Kit.slot(snap,target).receipts.size())
  result=Kit.commit(result.snapshot,recipe,receipt)
 if not result.ok:return result
 var next:=saved.duplicate(true);next.slots=result.snapshot.slots
 return {"ok":true,"state":next,"inventory":result.snapshot.inventory}
static func take(saved: Dictionary,inventory: Array,capacity: int=64)->Dictionary:
 if not opened(saved):return Kit.refuse("The Emperor's tomb is sealed.")
 if not DeadBracers.available(inventory):return Kit.refuse("You need the Bracers of the Dead to understand the Emperor.")
 if saved.remains or REMAINS in inventory:return Kit.refuse("You already carry the Emperor's remains.")
 if inventory.size()>=capacity:return Kit.refuse("Make room for the Emperor's remains.")
 var next:=saved.duplicate(true);next.remains=true
 var carried:=inventory.duplicate();carried.append(REMAINS)
 return {"ok":true,"state":next,"inventory":carried}
