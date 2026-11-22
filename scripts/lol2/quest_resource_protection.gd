extends RefCounted
## Modern protection only. The compiled recipe/model evidence owns quantities;
## this module checks a proposed pack AND proposed story state before effects.
const Bundled=preload("res://scripts/lol2/quest_resource_policy_data.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Areas=preload("res://scripts/lol2/game_areas.gd")
static var policy:Dictionary={}
static var policy_warning:=false
static var policy_loaded:=false
static func parse_policy(value:Variant)->Dictionary:
 if not value is Dictionary or value.get("version")!=1 or not value.get("obligations") is Array or value.obligations.is_empty() or not value.get("leaf_chain") is Dictionary:return {}
 for row in value.obligations:
  if not row is Dictionary or not row.get("name") is String or not row.get("reason") is String or not row.get("items") is Array or not row.get("definitions") is bool:return {}
  if not row.get("need") is int and not row.get("need") is float:return {}
  if not is_finite(float(row.need)) or row.need<1 or row.need!=int(row.need) or row.items.is_empty():return {}
  for item in row.items:
   if item is String and not item.is_empty():continue
   if row.definitions and (item is int or item is float) and is_finite(float(item)) and item==int(item) and item>=0 and item<256:continue
   return {}
  for field in ["done","slots","recoverable"]:
   if not row.get(field) is Array:return {}
  for source in row.slots+row.recoverable:
   if source is String and not source.is_empty():continue
   var path:Variant=source.path if source is Dictionary and source.get("area") is String and not source.area.is_empty() and source.get("path") is Array else source
   if not path is Array or path.is_empty():return {}
   for key in path:
    if not key is String or key.is_empty():return {}
  for condition in row.done:
   if not condition is Dictionary or not condition.get("path") is Array or condition.path.is_empty():return {}
   if condition.has("at_least"):return {} # No compiled row uses numeric thresholds.
   for field in ["truthy","all_committed"]:
    if condition.has(field) and not condition[field] is bool:return {}
   for key in condition.path:
    if not key is String:return {}
   if condition.get("all_committed",false):
    if not condition.get("targets") is Array or condition.targets.is_empty():return {}
    for target in condition.targets:
     if not target is String:return {}
  if row.has("quantity_profiles"):
   if not row.quantity_profiles is Dictionary:return {}
   for key in ["before_initiation","after_initiation","with_serum_before_initiation","with_serum","after_mix","complete"]:
    var profile:Variant=row.quantity_profiles.get(key)
    if not profile is Dictionary or (not profile.get("need") is int and not profile.get("need") is float):return {}
    if not is_finite(float(profile.need)) or profile.need<0 or profile.need!=int(profile.need):return {}
 var chain:Dictionary=value.leaf_chain
 for key in ["mix_path","trade_path","tribe_path","steps","trees"]:
  if not chain.get(key) is Array:return {}
 if not chain.get("growth_key") is String or not chain.get("harvest_key") is String:return {}
 return value
static func data()->Dictionary:
 if not policy_loaded:
  policy_loaded=true
  policy=parse_policy(Bundled.DATA.duplicate(true))
  if policy.is_empty() and not policy_warning:
   policy_warning=true;push_warning("Quest protection data is missing or invalid; item removals are held; pickups remain available.")
 return policy
static func value(quests:Dictionary,path:Array)->Variant:
 var at:Variant=quests
 for key in path:
  if not at is Dictionary:return null
  at=at.get(str(key))
 return at
static func past_larkhon(quests:Dictionary,area:String="")->bool:
 var chain:Dictionary=data().leaf_chain
 if value(quests,chain.mix_path)==true or quests.get("l13_altar",{}).get("stone_taken",false) or quests.get("l14_chamber_voices",{}).get("offered",false):return true
 return false # A level number or debug/F2 load is not a story receipt.
static func done(row:Dictionary,quests:Dictionary,area:String="")->bool:
 if row.get("before_larkhon_only",false) and past_larkhon(quests,area):return true
 for condition in row.done:
  var at:Variant=value(quests,condition.path)
  if condition.get("all_committed",false) and at is Dictionary:
   var complete:=true
   for target in condition.targets:
    if not at.get(target,{}) is Dictionary or at.get(target,{}).get("committed",false)!=true:complete=false
   if complete:return true
  if condition.get("truthy",false):
   if at is String and not at.is_empty():return true
   if at is bool and at:return true
 return false
static func needed(row:Dictionary,quests:Dictionary,pack:Array,area:String="")->int:
 if done(row,quests,area):return 0
 if not row.has("quantity_profiles"):return int(row.need)
 var chain:Dictionary=data().leaf_chain
 var profile:="before_initiation"
 if past_larkhon(quests,area):profile="after_mix"
 else:
  var initiated:bool=value(quests,chain.tribe_path)==true
  var serum:bool=value(quests,chain.trade_path)==true
  for id in pack:
   if Items.definition(id)==int(chain.serum_definition):serum=true;break
  if serum:profile="with_serum" if initiated else "with_serum_before_initiation"
  elif initiated:profile="after_initiation"
 return int(row.quantity_profiles[profile].need)
static func matches(row:Dictionary,id:Variant)->bool:
 if not id is String or id.is_empty():return false
 if id in row.items:return true
 if not row.definitions:return false
 var definition:int=Items.definition(id)
 if definition<0:definition=load("res://scripts/lol2/item_catalog.gd").definition(id)
 for candidate in row.items:
  if (candidate is int or candidate is float) and definition==int(candidate):return true
 return false
static func resources(row:Dictionary,pack:Array,quests:Dictionary,area:String="")->int:
 var seen:Array=[]
 for id in pack:
  if matches(row,id) and id not in seen:seen.append(id)
 for key in row.slots+row.recoverable:
  if key is Dictionary:
   if str(key.area)!=area:continue
   key=key.path
  var saved:Variant=value(quests,key) if key is Array else quests.get(str(key),{})
  if not saved is Dictionary:continue
  var slots:Array=saved.get("slots",{}).values()
  if saved.get("slot") is Dictionary:slots.append(saved.slot)
  for slot in slots:
   var id:Variant=slot.get("occupied","")
   if slot.get("committed",false) and matches(row,id) and id not in seen:seen.append(id)
 return seen.size()
static func early_leaf_progress(before:Dictionary,after:Dictionary,old_pack:Array,new_pack:Array)->bool:
 # These are the actual original mandatory chain exchanges. A random quest
 # flag or caller string is never an exemption. Future harvest is not counted
 # after these one-time exchanges have finished.
 for step in data().leaf_chain.steps:
  if value(before,step.receipt)==true or value(after,step.receipt)!=true:continue
  var leaf:String=str(value(after,step.leaf))
  if Items.definition(leaf)==117 and leaf in old_pack and leaf not in new_pack:
   if not str(step.output).is_empty() and step.output not in new_pack:continue
   return true
 return false
static func future_leaves(quests:Dictionary)->int:
 var chain:Dictionary=data().leaf_chain
 if not quests.get(chain.growth_key,{}).get("grown",false):return 0
 var picked:Array=quests.get(chain.harvest_key,{}).get("picked",[])
 var count:=0
 for target in chain.trees:
  if str(int(target)) not in picked:count+=1
 return count
static func refusal(before:Array,after:Array,quests:Dictionary,proposed:Dictionary,area:String="")->String:
 if data().is_empty():
  # With no trusted rules, preserve existing ownership but never freeze gains.
  for id in before:
   if after.count(id)<before.count(id):return "This item cannot be used right now."
  return ""
 for row in data().obligations:
  var demand:int=needed(row,proposed,after,area)
  var old_count:int=resources(row,before,quests,area)
  var new_count:int=resources(row,after,proposed,area)
  if new_count>=demand:continue
  var old_demand:int=needed(row,quests,before,area)
  if new_count>=old_count and demand<=old_demand:continue
  if row.name=="City pyramid":
   if early_leaf_progress(quests,proposed,before,after) and new_count+future_leaves(proposed)>=demand:continue
   if demand>1:
    var steps:Array=[]
    var chain:Dictionary=data().leaf_chain
    if value(proposed,chain.tribe_path)!=true:steps.append("the tribe's initiation")
    var serum:bool=value(proposed,chain.trade_path)==true
    for id in after:
     if Items.definition(id)==int(chain.serum_definition):serum=true;break
    if not serum:steps.append("the shaman")
    if not past_larkhon(proposed,area):steps.append("Larkhon")
    steps.append("the City's glass pyramid")
    return "Keep the remaining Silverleaves for "+", ".join(steps.slice(0,-1))+" and "+str(steps[-1])+"."
  return row.reason
 return ""
static func host_refusal(host:Object,before:Array,after:Array,changes:Dictionary={})->String:
 # Partial owner/unit doubles have no whole-game context. Every playable root
 # has the foundation snapshot contract; loads themselves do not use commit.
 if host==null or not host.has_method("area_snapshot"):return ""
 var quests:Dictionary=quest_view(host)
 var proposed:Dictionary=quests.duplicate()
 proposed.merge(changes,true)
 return refusal(before,after,quests,proposed,Areas.id_for(host))
static func quest_view(host:Object)->Dictionary:
 var bank:Variant=host.get("quest_state")
 if bank is Dictionary:return bank
 # Hive has separate checkpoint owners. Do NOT call area_handoff/snapshot:
 # their packing refreshes curse state. Observation here stays read-only.
 var carried:Variant=host.get("carried_quest_checkpoint")
 var result:Dictionary=carried.duplicate(true) if carried is Dictionary else {}
 var flute:Variant=host.get("flute_floor")
 if is_instance_valid(flute):
  var key:String=str(flute.get_script().get_script_constant_map().get("KEY",""))
  if not key.is_empty():result[key]=flute.checkpoint()
 return result
static func removing(host:Object,pack:Array,id:String)->String:
 var next:Array=pack.duplicate();next.erase(id)
 return host_refusal(host,pack,next)
