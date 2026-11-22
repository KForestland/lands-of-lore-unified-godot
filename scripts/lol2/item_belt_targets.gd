extends RefCounted
## Read-only discovery; only an explicit E calls the existing owner's transaction.
## Existing reach/aim, prerequisites and save receipts remain authoritative.
const DeadBracers=preload("res://scripts/lol2/dead_bracers_item.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
static func descriptor(owner:Node,key:String,definitions:Array,apply:Callable,ids:Array=[],native_e:bool=true,missing:String="")->Dictionary:
 return {"owner":owner,"key":str(owner.get_instance_id())+":"+key,"definitions":definitions,"ids":ids,"apply":apply,"native_e":native_e,"missing":missing}
static func accepts(target:Dictionary,id:Variant)->bool:
 if not preload("res://scripts/lol2/item_belt_state.gd").valid_id(id):return false
 return id in target.get("ids",[]) or Catalog.definition(id) in target.get("definitions",[])
static func pick(target:Dictionary,owned:Array)->String:
 for id in owned:
  if accepts(target,id):return id
 return ""
static func held_call(host:Node,id:String,action:Callable)->Variant:
 var previous:String=host.hand_item
 host.hand_item=id
 var result:Variant=action.call()
 # Owners may consume/clear the hand. Never resurrect a consumed selection.
 host.hand_item=previous if previous in host.item_effects.carried() else ""
 return result
static func find(host:Node)->Dictionary:
 var n:Node=host.get("flute_floor")
 if is_instance_valid(n) and n._active() and n.in_reach() and not n.occupied():return descriptor(n,"flute",[],func(id):return n.offer_item(id),[n.FLUTE])
 n=host.get_node_or_null("Act2Chargers")
 if is_instance_valid(n):
  var key:String=n.target()
  if not key.is_empty() and not n.globes[key].visible:return descriptor(n,key,[98],func(id):return n.interact(key,"insert",id))
 n=host.get_node_or_null("L10MainGate")
 if is_instance_valid(n) and not n.opened() and n.reachable():return descriptor(n,"sigil",[],func(id):return n.unlock(id),[n.SIGIL])
 n=host.get_node_or_null("L10Tombs")
 if is_instance_valid(n):
  var key:String=n.target()
  if not key.is_empty():return descriptor(n,key,[int(n.State.ROWS[key][1])],func(id):return n.offer(key,id))
 n=host.get_node_or_null("L10EmperorEntry")
 if is_instance_valid(n) and n.reachable() and not n.opened():return descriptor(n,"ankh",[97],func(id):return n.offer(id))
 n=host.get_node_or_null("L10Emperor")
 if is_instance_valid(n) and n.active():
  var key:String=n.target()
  if key=="143" and not n.State.opened(n.state()):return descriptor(n,key,[97],func(id):return n.interact(key,id))
  if n.State.COLORS.has(key) and n.State.Kit.slot(n.state(),key).occupied=="":return descriptor(n,key,[int(n.State.COLORS[key])],func(id):return n.interact(key,id))
 n=host.get_node_or_null("L10Priest")
 if is_instance_valid(n) and n.reachable() and n.state().urn_given and host.get_node("L10Tombs").opened("154") and DeadBracers.available(host.carried_collected) and not host.quest_state.get("l10_ankh",{}).get("slots",{}).has(n.Ankh.TRADE):return descriptor(n,"ashes",[],func(id):return n.exchange_ashes(id),[n.Ankh.FULL])
 n=host.get_node_or_null("L13ExitLock")
 if is_instance_valid(n) and n.reachable() and not n.State.unlocked(n.state()):return descriptor(n,"stone",[136],func(id):return n.interact("insert",id))
 n=host.get_node_or_null("L14FluteSlot")
 if is_instance_valid(n) and n.reachable() and not n.committed(n.state()):return descriptor(n,"flute",[96],func(id):return n.interact("insert",id))
 n=host.get_node_or_null("L14IdolPedestals")
 if is_instance_valid(n):
  for key in n.CASES:
   if n.reachable(key) and not n.Kit.slot(n.state(),key).committed:return descriptor(n,key,[],func(id):return n.offer(key,id),n.IDOLS)
 n=host.get_node_or_null("L14ShardBowls")
 if is_instance_valid(n):
  for key in n.BOWLS:
   if n.reach(key) and not n.Kit.slot(n.state(),key).committed:return descriptor(n,key,[],func(id):return n.offer(key,id),n.SHARDS)
 n=host.get_node_or_null("L16Greenhouse")
 if is_instance_valid(n) and n.aimed(n.PLATE,150.0) and n.state().silverleaf.is_empty():return descriptor(n,"leaf",[117],func(id):return held_call(host,id,n.place_silverleaf))
 n=host.get_node_or_null("L16SwChips")
 if is_instance_valid(n):
  var index:int=n.aimed_index()
  if index>=0 and not n._indexes().has(index):return descriptor(n,str(index),[],func(id):return held_call(host,id,func():return n.offer(index)),n.CHIP_IDS,false,"The pedestal takes an ivory chip.")
 n=host.get_node_or_null("L8TempleDoor")
 if is_instance_valid(n) and n.reachable() and not n.State.unlocked(n.state()):return descriptor(n,"stone",[136],func(id):return n.interact("insert",id))
 n=host.get_node_or_null("L8Tree")
 if is_instance_valid(n) and n.reachable() and not n.Slot.unlocked(n.state().lock):return descriptor(n,"shard",[105],func(id):return n.interact("insert",id))
 n=host.get_node_or_null("L8Larkhon")
 if is_instance_valid(n) and n.reachable() and not n.State.used(n.state()):return descriptor(n,"vapors",[128],func(id):return n.offer(id),[],false,"You need activated Larkhon Vapors.")
 n=host.get_node_or_null("L14Spiral")
 if is_instance_valid(n) and n.reachable() and not n.committed(n.state()):return descriptor(n,"stone",[136],func(id):return n.interact("insert",id))
 n=host.get_node_or_null("L14PriestRitual")
 if is_instance_valid(n):
  for key in n.BOWLS:
   if n.reach(n.BOWLS[key]) and not n.Kit.slot(n.state(),key).committed:return descriptor(n,key,[],func(id):return n.offer(key,id),[n.INGREDIENTS[key]])
 n=host.get_node_or_null("L14HopperPlatform")
 if is_instance_valid(n) and n.reach(n.POINT) and not n.complete(n.state()):
  # Preserve the owner's higher-priority E pickup when a fallen hopper is in view.
  for key in n.IDS:
   if host.act2_creatures.state.actors[key].health==0 and key not in n.state().collected and n.reach(host.act2_creatures.bodies[key].global_position+Vector3.UP*8):return {}
  return descriptor(n,"bodies",[],func(id):return n.place(id),n.IDS.map(func(index):return n.item(index)))
 n=host.get_node_or_null("L8Journey")
 if is_instance_valid(n):
  var location:String=n.target()
  if not location.is_empty():
   var point:Vector3=n.TARGETS[location]+(host.native_translation if host.get("native_translation")!=null else Vector3.ZERO)
   var delta:Vector3=point-host.camera.global_position
   if delta.length()>256 or (delta.length()>0.01 and (-host.camera.global_basis.z).dot(delta.normalized())<0.9):location=""
  if n.permitted("offer_daniel",location) and n.state().gift=="unoffered":return descriptor(n,"daniel",[],func(id):return n.interact("offer_daniel",id),[n.State.BLADE],true)
  if n.permitted("show_guard",location) and not n.state().admitted:return descriptor(n,"guard",[],func(id):return n.interact("show_guard",id),[n.State.BLADE],true)
 n=host.get("key_locks")
 if is_instance_valid(n) and n._ready_for_use():
  # Existing key pickup/retrieval, panel and sconce actions keep their own E.
  var original:Dictionary=n.target()
  if not original.is_empty() and (not original.has("lock") or int(original.lock) not in n.State.LOCKS or n.State.is_loaded(n.state,int(original.lock))):return {}
  for lock:int in n.State.LOCKS:
   if not original.is_empty() and int(original.lock)!=lock:continue
   if not n.State.is_loaded(n.state,lock) and host.can_reach_item(n.aim_point(lock)):
    return descriptor(n,str(lock),[],func(id):return {"ok":bool(held_call(host,id,n.use)),"reason":"The lock responds."},[n.State.KEY],not original.is_empty(),"The lock needs the museum skeleton key.")
 var dawn:Node=host.get("dawn")
 if is_instance_valid(dawn) and dawn.has_method("belt_wax"):
  var wax:String=dawn.belt_wax()
  if not wax.is_empty():return descriptor(dawn,"wax",[],func(id):return dawn.belt_offer_wax(id),[wax],false) # native_e=false: controller owns E; this is not a protection option.
 return {}

static func missing_hint(target:Dictionary)->String:
 if target.is_empty():return ""
 if not str(target.get("missing","")).is_empty():return str(target.missing)
 # Echo only information the existing owner already puts on screen. A belt
 # never discovers a recipe or reveals a hidden requirement from a data row.
 var owner:Node=target.owner
 var hint:Variant=owner.get("hint")
 if hint is Label and not hint.text.is_empty():return hint.text.trim_prefix("E — ").trim_prefix("E - ")
 if owner.has_method("interaction_hint"):return str(owner.interaction_hint()).trim_prefix("E — ").trim_prefix("E - ")
 return ""
