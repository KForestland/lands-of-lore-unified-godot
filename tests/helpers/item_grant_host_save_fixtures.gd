extends RefCounted
## Real production hosts/writers/readers. Spatial selectors and prerequisite
## setup are explicit component fixtures; these saves are not earned routes.
const Sites=preload("res://tests/helpers/item_grant_site_fixtures.gd")
const History=preload("res://tests/helpers/item_grant_history_fixtures.gd")
class Proxy extends Node3D:
 var target:Node3D
 var presentations:Array=[]
 var messages:Array=[]
 var carried_collected:Array:
  get:return target.carried_collected
  set(value):target.carried_collected=value
 var carried_inventory:Variant:
  get:return target.get("carried_inventory")
  set(value):target.carried_inventory=value
 var quest_state:Dictionary:
  get:return target.quest_state
  set(value):target.quest_state=value
 var hand_item:String:
  get:return target.hand_item
  set(value):target.hand_item=value
 var equipped_item:String:
  get:return target.equipped_item
  set(value):target.equipped_item=value
 var equipped_armor:String:
  get:return target.equipped_armor
  set(value):target.equipped_armor=value
 var player_form:int:
  get:return target.player_form
 var flying:bool:
  get:return target.flying
 var item_effects:Node:
  get:return target.item_effects
 var starting_magic:Node:
  get:return target.starting_magic
 var inventory:Node:
  get:return target.inventory
 var act2_items:Node:
  get:return target.act2_items
 func save_feedback(text:String):messages.append(text)
 func _save_feedback(text:String):messages.append(text)
 func set_equipped_item(id:String):target.set_equipped_item(id)
 func set_equipped_armor(id:String):target.set_equipped_armor(id)
class Tombs extends Node:
 var target:Node
 func opened(id:String)->bool:return target.opened(id)
static func rehost(ctx:Dictionary,scene:Node3D,seed:bool=true)->Node:
 var owner:Node=ctx.owner
 if seed:
  scene.carried_collected=ctx.host.carried_collected.duplicate()
  scene.quest_state.merge(ctx.host.saved_quests.duplicate(true),true)
  scene.hand_item=ctx.host.hand_item;scene.equipped_item=ctx.host.equipped_item
 var proxy:=Proxy.new();proxy.target=scene;scene.add_child(proxy)
 if scene.has_node("L10Tombs"):
  var tombs:=Tombs.new();tombs.name="L10Tombs";tombs.target=scene.get_node("L10Tombs");proxy.add_child(tombs)
 ctx.host.remove_child(owner);proxy.add_child(owner);owner.host=proxy
 return owner
static func seed_completed_spiral(scene:Node3D):
 # Schema-valid component prerequisites, not campaign-earned receipts. Use
 # the production transaction builder; no abbreviated {raised:4} save packet.
 var Bowls=preload("res://scripts/lol2/l14_shard_bowls.gd")
 var Spiral=preload("res://scripts/lol2/l14_spiral.gd")
 var Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
 var stone:="act2:L13_RC:dreamstone"
 var packet:Dictionary=scene.quest_state.get("act2_items",Sites.Items.initial()).duplicate(true)
 for id in Bowls.SHARDS+[stone]:
  if not id in packet.collected:packet.collected.append(id)
  scene.carried_collected.erase(id)
 scene.quest_state.act2_items=packet
 var bowls:Dictionary=Bowls.initial()
 for pair in [["405",Bowls.SHARDS[0]],["406",Bowls.SHARDS[1]]]:
  var snap:Dictionary=Kit.empty_snapshot([pair[1]])
  var recipe:Dictionary=Bowls.recipe(pair[0])
  var offered:Dictionary=Kit.offer(snap,recipe,pair[1],{"form":"human"});assert(offered.ok)
  var occupied:Dictionary=Kit.occupy(snap,offered.proposal);assert(occupied.ok)
  var committed:Dictionary=Kit.commit(occupied.snapshot,recipe,pair[0]);assert(committed.ok)
  bowls.slots.merge(committed.snapshot.slots)
 bowls.opened=2.0;scene.quest_state[Bowls.KEY]=bowls
 var spiral:Dictionary=Spiral.initial()
 var snap:Dictionary=Kit.empty_snapshot([stone]);var recipe:Dictionary=Spiral.recipe(stone)
 var offered:Dictionary=Kit.offer(snap,recipe,stone,{"form":"human"});assert(offered.ok)
 var occupied:Dictionary=Kit.occupy(snap,offered.proposal);assert(occupied.ok)
 var committed:Dictionary=Kit.commit(occupied.snapshot,recipe,Spiral.TARGET);assert(committed.ok)
 spiral.slots=committed.snapshot.slots;spiral.stone=stone;spiral.raised=4.0
 scene.quest_state[Spiral.KEY]=spiral;Sites.Items.sync(scene)
 assert(Bowls.validate(bowls,scene.quest_state).is_empty() and Spiral.validate(spiral,scene.quest_state).is_empty(),"Complete valid Temple prerequisite packets")
static func grant(scene:Node3D,area:String,tree:SceneTree)->Array:
 var names:Array=[]
 match area:
  "L1_DC":
   var population:Node=scene.guard_population
   var source_region:Dictionary={}
   for row in population.src.regions:
    if int(row.region)==1941:source_region=row
   assert(not source_region.is_empty())
   var centre:=Vector2.ZERO
   for p in source_region.polygon:centre+=Vector2(p[0],p[1])
   centre/=source_region.polygon.size()
   preload("res://scripts/lol2/scripted_creature_state.gd").contact(population.state,population.src,Vector3(centre.x,source_region.floor_min,centre.y),float(source_region.floor_min),0)
   assert(population.restore(population.checkpoint()).is_empty())
   assert(population.receive_damage("38",1000,true),"Actual production guard death")
   var ctx:=Sites.context("cave_guard38_loot","normal",tree)
   var owner:=rehost(ctx,scene,false);scene.guard38_loot=owner
   assert(owner.collect());ctx.host.free();names=["cave_guard38_loot"]
  "L3_DH":
   for name in ["museum_prism","museum_aloe_rule"]:
    var ctx:=Sites.context(name,"normal",tree);var owner:=rehost(ctx,scene,false)
    if name=="museum_prism":scene.prism=owner
    else:scene.aloe_pickups=owner
    assert(owner.use());ctx.host.free();names.append(name)
  "L4_HJ":
   var ctx:=Sites.context("jungle_world_item","normal",tree);var owner:=rehost(ctx,scene,false)
   assert(owner.collect());ctx.host.free();names=["jungle_world_item"]
   # Existing host callback, not a copied implementation. The native source
   # actor receipt is not claimed here; the writer's existing validator decides.
   scene._kityara_grant(int(scene.kityara.src.item.identity));names.append("kityara_knife")
  "L5_HC":
   var ctx:=Sites.context("hive_wax","normal",tree);var owner:=rehost(ctx,scene,false);scene.wax=owner
   assert(owner.collect());ctx.host.free();names=["hive_wax"]
  "L7_DH":
   var ctx:=Sites.context("dark_halls_loot","normal",tree);var owner:=rehost(ctx,scene,false)
   assert(owner.take());ctx.host.free();names=["dark_halls_loot"]
  "L8_SJ":
   var ctx:=Sites.context("l8_tree_slot","normal",tree);var owner:=rehost(ctx,scene)
   scene.quest_state.l14_post_shard={"version":1,"taken":true}
   assert(owner.interact("insert","act2:L14_HT:post_shard").ok);ctx.host.free();names=["l8_tree_slot"]
  "L9_DR":
   var ctx:=History.context("l9_pyre.gd::urn",tree);var owner:=rehost(ctx,scene)
   scene.quest_state.l10_priest={"version":1,"urn_given":true}
   assert(owner.urn("insert",owner.State.URN).ok)
   assert(owner.urn("retrieve").ok);ctx.host.free();names=["pyre_urn"]
  "L10_DC":
   var ctx:=Sites.context("l10_priest_urn","normal",tree);var owner:=rehost(ctx,scene)
   var blue:="act2:L10_DC:item45:charged:blue";scene.carried_collected.append(blue)
   scene.quest_state.act2_items.collected.append(Sites.Items.base_id(blue));scene.quest_state.act2_items.carried.append(blue)
   var result:Dictionary=preload("res://scripts/lol2/l10_tomb_state.gd").offer(preload("res://scripts/lol2/l10_tomb_state.gd").initial(),scene.carried_collected,"154",blue)
   assert(result.ok);scene.carried_collected=result.inventory;scene.quest_state.l10_tombs=result.state
   assert(owner.speak().ok);ctx.host.free();names=["l10_priest_urn"]
  "L12_CM":
   var ctx:=Sites.context("l12_frozen_bow","normal",tree);var owner:=rehost(ctx,scene)
   assert(owner.take().ok);ctx.host.free();names=["l12_frozen_bow"]
  "L14_HT":
   var ctx:=History.context("l14_post_shard.gd::take",tree);var owner:=rehost(ctx,scene)
   assert(owner.take().ok);ctx.host.free();names=["l14_post_shard"]
   seed_completed_spiral(scene)
   ctx=Sites.context("l14_trial_idol","normal",tree)
   scene.quest_state[ctx.owner.KEY]=ctx.host.saved_quests[ctx.owner.KEY].duplicate(true)
   owner=rehost(ctx,scene,false)
   assert(owner.take().ok);ctx.host.free();names.append("l14_trial_idol")
  "L16_CA":
   var ctx:=Sites.context("l16_fountain_ball","normal",tree);var owner:=rehost(ctx,scene)
   assert(owner.take(518).ok);ctx.host.free();names=["l16_fountain_ball"]
   ctx=History.context("l16_dry_fountain.gd::take",tree)
   scene.quest_state[ctx.owner.KEY]=ctx.host.saved_quests[ctx.owner.KEY].duplicate(true)
   owner=rehost(ctx,scene,false)
   assert(owner.take(0).ok);ctx.host.free();names.append("l16_dry_fountain")
  "L19_BC":
   var ctx:=Sites.context("l19_horn","normal",tree);var owner:=rehost(ctx,scene)
   assert(owner.take());ctx.host.free();names=["l19_horn"]
 return names
static func record(scene:Node3D,area:String,include_format:bool=false)->Dictionary:
 var state:Dictionary=scene.area_snapshot()
 var pack:Array
 if area=="L1_DC":pack=scene.carried_items()
 elif area=="L5_HC":pack=scene.carried_inventory.collected
 else:pack=scene.carried_collected
 var inventory:Dictionary=state.get("inventory",{})
 if area=="L1_DC":
  for key in ["collected","equipped_item","equipped_armor","item_effects","health","player_form","curse"]:
   if state.has(key):inventory[key]=state[key]
 var quests:Dictionary={}
 for key in state.get("quests",{}):
  if str(key).begins_with("act2_creatures_") or str(key).begins_with("native_"):continue
  quests[key]=state.quests[key]
 var owners:Dictionary={}
 if area=="L1_DC":owners.guard38_loot=scene.guard38_loot.checkpoint()
 if area=="L3_DH":owners={"prism":scene.prism.checkpoint(),"aloe":scene.aloe_pickups.checkpoint()}
 if area=="L5_HC":owners.wax=scene.wax.collected
 var result:Dictionary={"area":area,"actual_loaded_pack":pack,"inventory":inventory,"grant_quests":quests,"owner_receipts":owners}
 if include_format:
  result.save_format=state.format;result.save_version=state.version
 return Sites.canonical(result)
