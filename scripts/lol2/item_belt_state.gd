extends RefCounted
## Modern five-slot interface. Definitions reference owned items, never grant them.
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
static func initial()->Dictionary:return {"version":1,"slots":[-1,-1,-1,-1,-1],"active":2,"ages":[0,0,0,0,0],"clock":0}
static func validate(value:Variant)->String:
 if not value is Dictionary:return "Invalid item belt."
 var version:Variant=value.get("version")
 if not (version is int or version is float) or version!=1:return "Invalid item belt."
 for field in ["slots","ages"]:
  if not value.get(field) is Array or value[field].size()!=5:return "Invalid item belt slots."
 for n in value.ages+[value.get("active"),value.get("clock")]:
  if not (n is int or n is float) or not is_finite(float(n)) or n!=floorf(float(n)):return "Invalid item belt number."
 if value.active<0 or value.active>4 or value.clock<0 or value.clock>2147483647:return "Invalid item belt selection."
 var seen:=[]
 for i in 5:
  var d:Variant=value.slots[i]
  if d is String:
   if not (Catalog.Act2Items.valid(d) or Catalog.known(d)) or Catalog.definition(d)>=0:return "Invalid item belt identity."
  elif not (d is int or d is float) or not is_finite(float(d)) or d!=floorf(float(d)) or d < -1 or d>=170 or (d>=0 and not Catalog.Definitions.carriable(int(d))):return "Invalid item belt item."
  if not empty_ref(d) and d in seen:return "Duplicate item belt item."
  if value.ages[i]<0 or value.ages[i]>value.clock:return "Invalid item belt age."
  if not empty_ref(d):seen.append(d)
 return ""
static func canonical(value:Dictionary)->Dictionary:
 return {"version":1,"slots":value.slots.map(func(n):return n if n is String else int(n)),"ages":value.ages.map(func(n):return int(n)),"active":int(value.active),"clock":int(value.clock)}
static func resolve(value:Dictionary,index:int,owned:Array)->String:
 if index<0 or index>=5 or empty_ref(value.slots[index]):return ""
 for id in owned:
  var ref:Variant=identity(id)
  if not empty_ref(ref) and [ref].has(value.slots[index]):return str(id)
 return ""
static func put(value:Dictionary,id:Variant,owned:Array,index:int=-1)->bool:
 if id not in owned:return false
 var d:Variant=identity(id)
 if d is int and (d<0 or not Catalog.Definitions.carriable(d)):return false
 if d is String and not (Catalog.Act2Items.valid(d) or Catalog.known(d)):return false
 var empty_active:bool=resolve(value,int(value.active),owned).is_empty()
 var previous:int=value.slots.find(d)
 if index<0:index=previous if previous>=0 else value.slots.find(-1)
 if index<0:index=int(value.active)
 if index>=5:return false
 if previous>=0 and previous!=index:value.slots[previous]=-1;value.ages[previous]=0
 value.clock=mini(2147483647,int(value.clock)+1)
 value.slots[index]=d;value.ages[index]=value.clock
 if empty_active or previous==int(value.active):value.active=index
 return true
static func roll(value:Dictionary,owned:Array,direction:int)->bool:
 for step in range(1,6):
  var index:int=posmod(int(value.active)+step*direction,5)
  if not resolve(value,index,owned).is_empty():value.active=index;return true
 return false
static func label(id:Variant)->String:
 return {98:"Glass globe",99:"Yellow globe",100:"White globe",101:"Blue globe"}.get(Catalog.definition(id),Catalog.label(id))

static func identity(id:Variant)->Variant:
 # Museum transition lists can temporarily contain null. A belt is a view of
 # owned identities; malformed placeholders never become a slot or a match.
 if not id is String or id.is_empty():return -1
 var d:int=Catalog.definition(id)
 return d if d>=0 else id if Catalog.Act2Items.valid(id) or Catalog.known(id) else -1
static func valid_id(id:Variant)->bool:return not empty_ref(identity(id))
static func quest(definition:Variant)->bool:
 if definition is String:return Catalog.Act2Items.valid(definition)
 return definition in [11,22,29,35,68,69,72,73,74,76,77,78,79,80,81,85,86,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,112,117,119,128,136,168]
static func automatic(id:Variant)->bool:
 var d:Variant=identity(id)
 if empty_ref(d):return false
 return quest(d) or id in ["jungle:kityara:Empty_hand","act2:L19_BC:horn","act2:L12_CM:blue_bow","museum:control181:Tho_Broken"] or not Catalog.stored_school(id).is_empty()
static func pickup(value:Dictionary,id:Variant,owned:Array)->bool:
 if not automatic(id) or identity(id) in value.slots:return false
 var index:int=value.slots.find(-1)
 if index<0:
  var age:int=2147483647
  for i in 5:
   if not quest(value.slots[i]) and int(value.ages[i])<age:index=i;age=int(value.ages[i])
 if index<0:return false # All five quest items stay; the new item remains in the pack.
 var empty:bool=value.slots.all(empty_ref)
 var added:bool=put(value,id,owned,index)
 if added and empty:value.active=index
 return added

static func empty_ref(value:Variant)->bool:return (value is int or value is float) and value==-1
static func same_identity(first:Variant,second:Variant)->bool:
 var ref:Variant=identity(first)
 return not empty_ref(ref) and [ref].has(identity(second))
