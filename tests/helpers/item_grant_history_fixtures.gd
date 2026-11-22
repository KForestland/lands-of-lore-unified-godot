extends RefCounted
## All table2.9 production call sites; environment/view doubles only. Explicit
## prehistory cases expose append-vs-once where the site's own guard permits it.
const Sites=preload("res://tests/helpers/item_grant_site_fixtures.gd")
const Items=Sites.Items
const CASES={
 "l12_citadel.gd::search_body":"always","l12_citadel.gd::throw_picture":"always",
 "l12_frozen_bow.gd::take":"always","l12_niche_armor.gd::take":"always",
 "l13_altar.gd::enchant":"always","l13_altar.gd::take_stone":"always","l13_dawn_prison.gd::finish":"always",
 "l14_hopper_platform.gd::take":"always","l14_post_shard.gd::take":"always","l14_trials.gd::take":"always",
 "l8_dawn.gd::interact":"always","l8_tribe.gd::offer_shaman":"always","l8_larkhon.gd::mix":"always",
 "act2_world_items.gd::take":"always","l10_priest.gd::grant":"always","l10_silverleaf_harvest.gd::pick":"always",
 "l16_dry_fountain.gd::take":"once","l16_fountain_ball.gd::take":"once",
 "l10_emperor.gd::interact":"once","l10_emperor.gd::collect_remains":"once","l10_priest.gd::exchange_ashes":"once",
 "l9_pyre.gd::urn":"once","l19_belial_horn.gd::take":"once","l19_dawn_curse.gd::_grant_ruby":"once"}
class Citadel extends "res://scripts/lol2/l12_citadel.gd":
 func _ready():pass
 func active()->bool:return true
 func reachable(_point:Vector3)->bool:return true
 func ground_hit()->Dictionary:return {"position":Vector3.ZERO}
class Armor extends "res://scripts/lol2/l12_niche_armor.gd":
 func _ready():pass
 func active()->bool:return true
 func reachable()->bool:return true
 func restore():host.presentations.append("armor")
class Altar extends "res://scripts/lol2/l13_altar.gd":
 func _ready():pass
 func active()->bool:return true
 func reachable(_point:Vector3)->bool:return true
 func boss_dead()->bool:return true
class Prison extends "res://scripts/lol2/l13_dawn_prison.gd":
 func _ready():pass
 func play(next:String):cue=next
 func leave():host.presentations.append("prison-leave")
class Hopper extends "res://scripts/lol2/l14_hopper_platform.gd":
 func _ready():pass
 func reach(_point:Vector3)->bool:return true
 func restore():host.presentations.append("hopper")
class Post extends "res://scripts/lol2/l14_post_shard.gd":
 func _ready():pass
 func reachable()->bool:return true
 func restore():host.presentations.append("post")
class Dawn extends "res://scripts/lol2/l8_dawn.gd":
 func _ready():pass
 func available()->bool:return true
 func reachable()->bool:return true
class Tribe extends "res://scripts/lol2/l8_tribe.gd":
 func _ready():pass
class Larkhon extends "res://scripts/lol2/l8_larkhon.gd":
 func _ready():pass
class WorldItems extends "res://scripts/lol2/act2_world_items.gd":
 func _ready():pass
 func available(id:String,_explain_shield:bool=false)->bool:return sprites.has(id) and sprites[id].visible
class DryFountain extends "res://scripts/lol2/l16_dry_fountain.gd":
 func _ready():pass
 func restore():host.presentations.append("dry-fountain")
class Emperor extends "res://scripts/lol2/l10_emperor.gd":
 func _ready():pass
 func reachable(_target:String)->bool:return true
 func restore():host.presentations.append("emperor")
 func leave_room():room_active=false;host.presentations.append("emperor-leave")
class Pyre extends "res://scripts/lol2/l9_pyre.gd":
 func _ready():pass
 func active()->bool:return true
 func reachable(_point:Vector3)->bool:return true
 func present():host.presentations.append("pyre")
class Ruby extends "res://scripts/lol2/l19_dawn_curse.gd":
 func _ready():pass
class Act2Views extends Node:
 var calls:=0
 func restore():calls+=1
class Builder extends RefCounted:
 var state:Dictionary={}
 var items:Dictionary=Items.initial()
 var pack:Array=[]
 var kind:=""
 func action()->Dictionary:
  var result:Dictionary
  if kind=="priest":result=preload("res://scripts/lol2/l10_priest.gd").grant(state,pack,items,64)
  else:result=preload("res://scripts/lol2/l10_silverleaf_harvest.gd").pick(state,pack,items,"159",64)
  if result.ok:state=result.state;items=result.items;pack=result.inventory
  return result
static func seed_pack(host:Node3D,pack:Array):
 host.carried_collected=pack.duplicate()
 host.saved_quests.act2_items={"version":1,"collected":pack.filter(func(id):return Items.valid(id)),"carried":pack.filter(func(id):return Items.valid(id))}
static func emperor_context(host:Node3D,owner:Node,remains:bool):
 var state:Dictionary=owner.State.initial()
 var inventory:Array=[owner.State.BRACERS,"act2:L10_DC:item45:charged:blue","act2:L10_DC:item44:charged:yellow","act2:L10_DC:item9:charged:white",owner.State.Ankh.ANKH]
 seed_pack(host,inventory)
 for pair in [["125",inventory[1]],["126",inventory[2]],["127",inventory[3]],["143",inventory[4]]]:
  var result:Dictionary=owner.State.act(state,host.carried_collected,pair[0],pair[1]);assert(result.ok,"Valid original Emperor fixture")
  state=result.state;host.carried_collected=result.inventory
 if remains:state.remains=true;host.carried_collected.append(owner.State.REMAINS)
 host.saved_quests.l10_emperor=state
static func context(id:String,tree:SceneTree)->Dictionary:
 var reused:Dictionary={"l12_frozen_bow.gd::take":"l12_frozen_bow","l14_trials.gd::take":"l14_trial_idol","l16_fountain_ball.gd::take":"l16_fountain_ball","l19_belial_horn.gd::take":"l19_horn"}
 if reused.has(id):
  var ctx:=Sites.context(reused[id],"normal",tree)
  ctx.history_id={"l12_frozen_bow":"act2:L12_CM:blue_bow","l14_trial_idol":"act2:L14_HT:trial_idol371","l16_fountain_ball":"act2:L16_CA:lichen518","l19_horn":"act2:L19_BC:horn"}[reused[id]]
  return ctx
 var host:=Sites.Host.new();Sites.init_host(host,tree)
 var owner:Variant
 var action:Callable
 var owner_state:Callable
 var history_id:=""
 var pack:Callable=func():return host.carried_collected
 match id:
  "l12_citadel.gd::search_body":
   owner=Citadel.new();history_id=owner.State.PICTURE;action=owner.search_body;owner_state=owner.state
  "l12_citadel.gd::throw_picture":
   owner=Citadel.new();var state:Dictionary=owner.State.initial();state.searched=true;state.armed=true;host.saved_quests[owner.State.KEY]=state
   seed_pack(host,[owner.State.PICTURE]);host.hand_item=owner.State.PICTURE;history_id=owner.State.CHARM
   action=func():return owner.throw_picture(owner.State.PICTURE)
   owner_state=owner.state
  "l12_niche_armor.gd::take":
   owner=Armor.new();var state:Dictionary=owner.initial();state.revealed=true;host.saved_quests[owner.KEY]=state;history_id=owner.ITEM;action=owner.take;owner_state=owner.state
  "l13_altar.gd::enchant","l13_altar.gd::take_stone":
   owner=Altar.new();var sword:="cave:guard38:Short_Sword";seed_pack(host,[sword]);host.equipped_item=sword
   if id.ends_with("::take_stone"):
    var prepared:Dictionary=owner.State.enchant(owner.State.initial(),host.carried_collected,sword,sword,true);assert(prepared.ok)
    host.saved_quests[owner.State.KEY]=prepared.state;host.carried_collected=prepared.inventory;host.equipped_item=prepared.state.output;history_id=owner.State.STONE;action=owner.take_stone
   else:history_id=owner.State.DARK;action=owner.enchant
   owner_state=owner.state
  "l13_dawn_prison.gd::finish":
   owner=Prison.new();seed_pack(host,["act2:L13_RC:dreamstone"]);host.saved_quests[owner.KEY]={"version":1,"visited":true,"released":false}
   owner.cue="600";owner.pending={"item":"act2:L13_RC:dreamstone"};owner.button=Button.new();owner.add_child(owner.button)
   history_id=owner.Release.REWARD;action=owner.finish;owner_state=owner.state
  "l14_hopper_platform.gd::take":
   owner=Hopper.new();var state:Dictionary=owner.initial();state.activated=true;host.saved_quests[owner.KEY]=state
   host.act2_creatures.state.actors["91"]={"health":0};var body:=Node3D.new();host.add_child(body);host.act2_creatures.bodies["91"]=body
   history_id=owner.item("91")
   action=func():return owner.take("91")
   owner_state=owner.state
  "l14_post_shard.gd::take":
   owner=Post.new();history_id=owner.ITEM;action=owner.take;owner_state=owner.state
  "l8_dawn.gd::interact":
   owner=Dawn.new();seed_pack(host,[owner.State.BRACERS]);host.equipped_item=owner.State.BRACERS;history_id=owner.State.TOKEN;action=owner.interact;owner_state=owner.state
  "l8_tribe.gd::offer_shaman":
   owner=Tribe.new();var state:Dictionary=owner.State.initial();state.phase="complete";host.saved_quests[owner.State.KEY]=state
   var journey:=Sites.Journey.new();journey.name="L8Journey";host.add_child(journey)
   var leaf:="act2:L10_DC:silverleaf159";seed_pack(host,[leaf]);history_id="act2:L8_SJ:shaman_amaranth"
   action=func():return owner.offer_shaman(leaf)
   owner_state=owner.state
  "l8_larkhon.gd::mix":
   owner=Larkhon.new();var leaf:="act2:L10_DC:silverleaf159";var serum:="act2:L8_SJ:shaman_amaranth";seed_pack(host,[leaf,serum]);host.hand_item=serum;history_id=owner.State.VAPORS
   action=func():return owner.mix(serum,true)
   owner_state=owner.state
  "act2_world_items.gd::take":
   owner=WorldItems.new();history_id="act2:L10_DC:item48";var sprite:=Sprite3D.new();owner.add_child(sprite);owner.sprites[history_id]=sprite
   action=func():return owner.take(history_id)
   owner_state=func():return {"visible":sprite.visible}
  "l10_priest.gd::grant","l10_silverleaf_harvest.gd::pick":
   owner=Builder.new()
   if id.begins_with("l10_priest"):
    owner.kind="priest";owner.state=preload("res://scripts/lol2/l10_priest.gd").initial();owner.pack=["act2:L9_DR:item55"];owner.items={"version":1,"carried":owner.pack.duplicate(),"collected":owner.pack.duplicate()};history_id="act2:L10_DC:priest_urn"
   else:owner.kind="silverleaf";owner.state=preload("res://scripts/lol2/l10_silverleaf_harvest.gd").initial();history_id="act2:L10_DC:silverleaf159"
   action=owner.action
   owner_state=func():return owner.state
   pack=func():return owner.pack
  "l16_dry_fountain.gd::take":
   owner=DryFountain.new();host.saved_quests[owner.KEY]=owner.apply_break(owner.initial());history_id=owner.clump_id(0)
   action=func():return owner.take(0)
   owner_state=owner.state
  "l10_emperor.gd::interact","l10_emperor.gd::collect_remains":
   owner=Emperor.new();emperor_context(host,owner,id.ends_with("::interact"));history_id=owner.State.REMAINS
   if id.ends_with("::interact"):action=func():return owner.interact("125")
   else:owner.room_active=true;action=owner.collect_remains
   owner_state=owner.state
  "l10_priest.gd::exchange_ashes":
   owner=Sites.Priest.new();var tombs:=Sites.Tombs.new();tombs.name="L10Tombs";host.add_child(tombs);host.saved_quests[owner.KEY]={"version":1,"urn_given":true}
   seed_pack(host,[owner.BRACERS,owner.Ankh.FULL]);host.saved_quests.act2_items.collected.append(owner.URN);history_id=owner.Ankh.ANKH
   action=func():return owner.exchange_ashes(owner.Ankh.FULL)
   owner_state=owner.state
  "l9_pyre.gd::urn":
   owner=Pyre.new();var state:Dictionary=owner.State.initial();state.holding=true
   var placed:Dictionary=owner.State.place_body(state,[owner.ALTAR.x,owner.ALTAR.y,owner.ALTAR.z]);assert(placed.ok)
   state=placed.state;state.phase=3;state.orbs=["1205","1206"];state.burn=owner.State.DURATION;host.saved_quests[owner.KEY]=state
   seed_pack(host,[owner.State.URN]);host.act2_items=Act2Views.new();host.add_child(host.act2_items);history_id=owner.State.FULL
   action=func():return owner.urn("insert",owner.State.URN)
   owner_state=owner.state
  "l19_dawn_curse.gd::_grant_ruby":
   owner=Ruby.new();history_id=owner.RUBY_ID;action=owner._grant_ruby;owner_state=owner.state
  _:assert(false,"Missing history row "+id)
 if owner is Node:owner.host=host;host.add_child(owner)
 return {"host":host,"owner":owner,"action":action,"owner_state":owner_state,"pack":pack,"history_id":history_id}
const BLOCKING_GUARDS={
 "l12_citadel.gd::search_body":["l12_citadel.gd","if state().searched:"],
 "l12_citadel.gd::throw_picture":["l12_citadel_state.gd","if not s.searched or not s.armed or broken(s):"],
 "l12_frozen_bow.gd::take":["l12_frozen_bow.gd","if not active() or not reachable() or state().remaining<=0 or state().taken:"],
 "l12_niche_armor.gd::take":["l12_niche_armor.gd","if state().taken or ITEM in host.carried_collected:"],
 "l13_altar.gd::enchant":["l13_altar_state.gd","if enchanted(s):"],
 "l13_altar.gd::take_stone":["l13_altar_state.gd","if s.stone_taken:"],
 "l13_dawn_prison.gd::finish":["l13_dawn_release.gd","if completed(s):"],
 "l14_hopper_platform.gd::take":["l14_hopper_platform.gd","if id not in IDS or not state().activated or pop.state.actors[id].health>0 or id in state().collected:"],
 "l14_post_shard.gd::take":["l14_post_shard.gd","if state().taken:"],
 "l14_trials.gd::take":["l14_trials.gd","if prop in state().idols:"],
 "l8_dawn.gd::interact":["l8_dawn_state.gd","if completed(s) or TOKEN in inventory:"],
 "l8_tribe.gd::offer_shaman":["l8_shaman_trade.gd","if completed(s) or SERUM in inventory:"],
 "l8_larkhon.gd::mix":["l8_larkhon.gd","return not State.mixed(state())"],
 "act2_world_items.gd::take":["act2_world_items.gd","if not available(id) or id in host.carried_collected:"],
 "l10_priest.gd::grant":["l10_priest.gd","if saved.urn_given or URN in items.collected:"],
 "l10_silverleaf_harvest.gd::pick":["l10_silverleaf_harvest.gd","if target in s.picked or id in items.collected:"]}
static func packet(ctx:Dictionary)->Dictionary:
 return ctx.owner.items if ctx.owner is Builder else ctx.host.saved_quests.get("act2_items",Items.initial())
static func snapshot(ctx:Dictionary)->Dictionary:
 var result:Dictionary=Sites.snapshot(ctx)
 result.packet=Sites.canonical(packet(ctx))
 if ctx.owner is Prison:result.prison_button=ctx.owner.button.text
 if ctx.owner is Pyre:result.world_item_restore_calls=ctx.host.act2_items.calls
 return result
static func guard_reference(id:String)->Dictionary:
 assert(BLOCKING_GUARDS.has(id),"Every always row must name a repeat path or the real refusing guard: "+id)
 var record:Array=BLOCKING_GUARDS[id]
 var path:="scripts/lol2/"+str(record[0]);var lines:=FileAccess.get_file_as_string("res://"+path).split("\n")
 for line in lines.size():
  if record[1] in lines[line]:return {"source":path+":"+str(line+1),"guard":lines[line].strip_edges()}
 assert(false,"Guard moved or changed; audit fixture: "+id)
 return {}
static func refused(ctx:Dictionary,value:Variant)->bool:
 if value is Dictionary:return value.get("ok")==false
 if value is bool:return not value
 return ctx.owner is Prison and ctx.owner.button.text=="Dawn is already free."
static func run_history(tree:SceneTree)->Dictionary:
 var output:Dictionary={}
 for id in CASES:
  var row:Dictionary={"guard":CASES[id],"variants":{}}
  for variant in ["normal","prehistory","full64"]:
   var ctx:=context(id,tree)
   if variant=="prehistory":packet(ctx).collected.append(ctx.history_id)
   if variant=="full64":Sites.fill64(ctx.owner.pack if ctx.owner is Builder else ctx.host.carried_collected)
   var before:=snapshot(ctx)
   var result:Variant=ctx.action.call()
   var after:=snapshot(ctx)
   var repeated:Variant=ctx.action.call()
   var after_repeat:=snapshot(ctx)
   row.variants[variant]={"before":before,"result":Sites.canonical(result),"after":after,"repeat_result":Sites.canonical(repeated),"repeat":after_repeat}
   if variant=="normal":
    assert(ctx.history_id in after.packet.collected,"Normal history row actually executes: "+id)
    if CASES[id]=="always":
     if refused(ctx,repeated):
      assert(after.packet==after_repeat.packet,"Refused repeated always site preserves the entire packet: "+id)
      row.second_call_blocked=guard_reference(id)
      row.second_call_blocked.refusal_observed=true
      row.second_call_blocked.packet=after_repeat.packet
     else:
      assert(after.packet!=after_repeat.packet,"Allowed repeated always call must pin its second packet: "+id)
      row.second_call={"path":"Same real production method, existing post-first-call owner state and inventory","packet":after_repeat.packet}
   ctx.host.free()
  if CASES[id]=="always":assert(row.has("second_call")!=row.has("second_call_blocked"),"Exactly one repeat qualification per always row")
  output[id]=row
 return output
