extends RefCounted
## Original [0x26E58] is global section1, not a per-level script-local buffer.
## Values stay unknown until an actual writer/explicit legacy migration supplies them.
static func empty()->Dictionary:return {"version":1,"locals_e58":{}}
static func error(value:Variant)->String:
 if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("locals_e58") is Dictionary or value.locals_e58.size()>65536:return "Invalid global script cells."
 for key in value.locals_e58:
  if not key is String or not key.is_valid_int() or str(int(key))!=key or int(key)<0 or int(key)>65535:return "Invalid global script index."
  var byte:Variant=value.locals_e58[key]
  if not (byte is int or byte is float) or not is_finite(float(byte)) or byte!=int(byte) or byte<0 or byte>255:return "Invalid global script byte."
 return ""
static func canonical(value:Dictionary)->Dictionary:
 var cells:Dictionary={}
 for key in value.locals_e58:cells[str(key)]=int(value.locals_e58[key])
 return {"version":1,"locals_e58":cells}
static func legacy(bank:Variant,preferred:String)->Dictionary:
 var cells:Dictionary={};var ambiguous:Dictionary={}
 if not bank is Dictionary:return empty()
 for area in bank:
  if not bank[area] is Dictionary or not bank[area].get("locals_e58") is Dictionary:continue
  for raw_key in bank[area].locals_e58:
   var key:=str(raw_key);var value:Variant=bank[area].locals_e58[raw_key]
   if cells.has(key) and cells[key]!=value:ambiguous[key]=true
   cells[key]=value
 for key in ambiguous:cells.erase(key)
 # Old banks cannot tell which inactive level wrote last. The actual saved
 # level is authoritative for its known cells; ambiguous others stay unknown.
 var current:Variant=bank.get(preferred,{})
 if current is Dictionary and current.get("locals_e58") is Dictionary:
  for key in current.locals_e58:cells[str(key)]=current.locals_e58[key]
 return {"version":1,"locals_e58":cells}
static func runtime(value:Dictionary)->Dictionary:
 var result:Dictionary={}
 for key in value.locals_e58:result[int(key)]=int(value.locals_e58[key])
 return result
