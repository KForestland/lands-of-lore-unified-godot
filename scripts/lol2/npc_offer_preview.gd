extends RefCounted
## Refusal hints are read-only. No Node, Resource, Callable or other Object
## from a context hook enters the copied native state evaluator.
static func plain(value:Variant,depth:int=0)->bool:
 if depth>32:return false
 match typeof(value):
  TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME:return true
  TYPE_FLOAT:return is_finite(value)
  TYPE_ARRAY:
   for item in value:
    if not plain(item,depth+1):return false
   return true
  TYPE_DICTIONARY:
   for key in value:
    if not plain(key,depth+1) or not plain(value[key],depth+1):return false
   return true
 return false
static func packet(state:Dictionary,source:Dictionary,context:Dictionary,extra:Dictionary={})->Dictionary:
 if not plain([state,source,context,extra]):return {}
 return {"state":state.duplicate(true),"source":source.duplicate(true),"context":context.duplicate(true),"extra":extra.duplicate(true)}
static func say(host:Object,line:String)->bool:
 if not is_instance_valid(host) or line.is_empty():return false
 if host.has_method("save_feedback"):host.call("save_feedback",line);return true
 if host.has_method("_save_feedback"):host.call("_save_feedback",line);return true
 return false
static func item_name(identity:int)->String:
 var definitions=preload("res://scripts/lol2/item_definitions.gd")
 return str(definitions.label(definitions.by_identity(identity)))
