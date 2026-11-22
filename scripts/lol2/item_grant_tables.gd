extends RefCounted
const Definitions=preload("res://scripts/lol2/item_definitions.gd")
## Immutable shipped grant policies; tests can provide an explicit isolated cache.
const ROOT:="res://scripts/lol2/item_grants/"
static var _cache:Dictionary={}
static func table(area:String)->Dictionary:
 if not _cache.has(area):
  var path:=ROOT+area+".json"
  var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
  _cache[area]=raw if raw is Dictionary and int(raw.get("version",0))==1 and raw.get("area")==area else {}
 return _cache[area]
static func command(area:String,offset:int)->Dictionary:
 return table(area).get("commands",{}).get(str(offset),{})
static func id_of(area:String,offset:int)->String:return "act2:"+area+":grant"+str(offset)
static func for_id(id:String)->Dictionary:
 if id.get_slice(":",0)!="act2" or id.count(":")!=2:return {}
 var area:=id.get_slice(":",1);var tail:=id.get_slice(":",2)
 if not tail.begins_with("grant"):return {}
 var number:=tail.trim_prefix("grant")
 if not number.is_valid_int() or str(int(number))!=number or int(number)<0:return {}
 var row:=command(area,int(number))
 return row # Saved ids remain valid after a policy is disabled; admission is native()'s job.

static func inventory_row(id:String)->Dictionary:
 var row:=for_id(id)
 if row.is_empty():return {}
 var index:=int(row.get("definition",-1));var definition:Dictionary=Definitions.row(index)
 if definition.is_empty() or int(definition.identity)!=int(row.get("identity",-1)):return {}
 return {"id":id,"definition":index,"identity":int(definition.identity),"name":str(definition.name),"label":str(definition.label),"icon":Definitions.icon(index),"handler":int(definition.handler),"grade":"Explicit native grant policy; original callee/argument meaning remains UNKNOWN"}
