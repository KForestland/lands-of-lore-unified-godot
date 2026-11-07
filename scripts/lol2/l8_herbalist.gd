extends RefCounted
## Fresh-visit HERB_.WOM hotspot0/1/2 grants, flags200..205; later flag206 bonus is separate.
const KINDS := ["sap","amber","aloe"]
const DEFINITIONS := {"sap":111,"amber":112,"aloe":110}
static func ids() -> Array:
 var result:Array=[]
 for kind in KINDS:
  for n in 2:result.append("jungle:herb:"+kind+":"+str(n))
 return result
static func valid(id: Variant)->bool:return id is String and id in ids()
static func kind(id: String)->String:return id.get_slice(":",2) if valid(id) else ""
static func definition(id: String)->int:return DEFINITIONS.get(kind(id),-1)
static func initial()->Dictionary:return {"version":1,"collected":[]}
static func validate(state: Variant)->String:
 if not state is Dictionary or state.size()!=2 or state.get("version")!=1 or not state.get("collected") is Array:return "Invalid herbalist state."
 var seen:={}
 for id in state.collected:
  if not valid(id) or seen.has(id):return "Invalid herbalist pickup identity."
  seen[id]=true
 return ""
static func pick(state: Dictionary, inventory: Array, requested: String, admitted: bool)->Dictionary:
 var error:=validate(state)
 if not error.is_empty():return {"ok":false,"reason":error}
 if not admitted:return {"ok":false,"reason":"Enter the village first."}
 if requested not in KINDS:return {"ok":false,"reason":"Choose a jar."}
 if inventory.size()>=64:return {"ok":false,"reason":"Inventory full."}
 for id in ids():
  if kind(id)!=requested or id in state.collected:continue
  if id in inventory:return {"ok":false,"reason":"This item is already carried."}
  var next:=state.duplicate(true)
  var carried:=inventory.duplicate()
  next.collected.append(id);carried.append(id)
  return {"ok":true,"state":next,"inventory":carried,"notice":{"sap":"You take ironwood sap.","amber":"You take amber.","aloe":"You take cave aloe."}[requested]}
 return {"ok":false,"reason":"There is no more to take from this jar."}
