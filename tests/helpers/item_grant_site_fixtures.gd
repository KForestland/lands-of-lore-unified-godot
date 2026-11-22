extends RefCounted
## Behaviour baselines call the existing production owner methods. Only spatial
## selectors and presentation are doubled. These are isolated component cases,
## never earned saves or real-input evidence. Production owners remain unused by
## ItemGrants until these baselines and the real host saves are complete.
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const SITE_NAMES=["museum_prism","museum_aloe_rule","jungle_world_item","kityara_knife","hive_wax","dark_halls_loot","l8_tree_slot","l10_priest_urn","l12_frozen_bow","l14_trial_idol","l16_fountain_ball","l19_horn","cave_guard38_loot"]
class Effects extends Node:
 var saved:Dictionary={"journal":[]}
 func state()->Dictionary:return saved
class Hud extends CanvasLayer:
 var refreshes:=0
 func refresh_equipment():refreshes+=1
class Magic extends Node:
 var learned_groups:Array=[]
 func learn_spell_group(group:String):
  if group not in learned_groups:learned_groups.append(group)
 func world_active()->bool:return true
 func health()->int:return 30
class Journey extends Node:
 func target()->String:return "village"
class Population extends Node:
 var state:Dictionary={"actors":{}}
 var bodies:Dictionary={}
class Tombs extends Node:
 func opened(id:String)->bool:return id=="154"
class Host extends Node3D:
 var carried_collected:Array=[]
 var carried_inventory:Variant=null
 var saved_quests:Dictionary={"act2_items":{"version":1,"collected":[],"carried":[]}}
 var sync_packets:Array=[]
 var quest_state:Dictionary:
  get:
   for frame in get_stack():
    if str(frame.source).ends_with("/act2_items_catalog.gd") and frame.function=="sync":
     sync_packets.append(saved_quests.get("act2_items",Items.initial()).duplicate(true));break
   return saved_quests
  set(value):saved_quests=value
 var messages:Array=[]
 var presentations:Array=[]
 var item_effects:Node
 var interface_hud:CanvasLayer
 var hand_item:=""
 var equipped_item:=""
 var equipped_armor:=""
 var inventory:Node
 var starting_magic:Node
 var act2_items:Node
 var act2_creatures:Node
 var flying:=false
 var player_form:=0
 func save_feedback(text:String):messages.append(text)
 func _save_feedback(text:String):messages.append(text)
 func set_equipped_item(id:String):equipped_item=id
 func set_equipped_armor(id:String):equipped_armor=id
class Prism extends "res://scripts/lol2/museum_prism.gd":
 func reachable()->bool:return not taken
 func restore(value:bool)->void:taken=value;host.presentations.append("prism:"+str(value))
class Aloe extends "res://scripts/lol2/museum_aloe.gd":
 func offered()->int:return -1 if state.taken[0] else 0
 func present()->void:host.presentations.append("aloe")
class JungleItem extends "res://scripts/lol2/jungle_world_items.gd":
 func _ready():pass
 func target()->int:return -1 if 1 in history().collected else 1
class Wax extends "res://scripts/lol2/hive_wax.gd":
 func _ready():pass
 func target()->bool:return not collected
 func restore(value:bool)->void:collected=value;host.presentations.append("wax:"+str(value))
class DarkLoot extends "res://scripts/lol2/dark_halls_loot.gd":
 func target()->Dictionary:
  var row:Dictionary=source.controls[0]
  return {} if int(taken().get(str(int(row.control)),0))>=row.grants.size() else row
class TreeSlotFixture extends "res://scripts/lol2/l8_tree.gd":
 func _ready():pass
 func reachable()->bool:return true
 func restore():host.presentations.append("tree")
class Priest extends "res://scripts/lol2/l10_priest.gd":
 func _ready():pass
 func available()->bool:return true
 func reachable()->bool:return true
class Bow extends "res://scripts/lol2/l12_frozen_bow.gd":
 func _ready():pass
 func active()->bool:return true
 func reachable()->bool:return true
 func restore():host.presentations.append("bow")
class Trials extends "res://scripts/lol2/l14_trials.gd":
 func _ready():pass
 func reachable(_point:Vector3)->bool:return true
 func restore():host.presentations.append("trials")
class Ball extends "res://scripts/lol2/l16_fountain_ball.gd":
 func _ready():pass
 func restore()->void:host.presentations.append("ball")
class Horn extends "res://scripts/lol2/l19_belial_horn.gd":
 func _ready():pass
 func at_pipe()->bool:return true
class CaveLoot extends "res://scripts/lol2/cave_guard38_loot.gd":
 func aimed()->bool:return not state.taken
 func present()->void:host.presentations.append("cave-loot")
class KityaraData extends Node3D:
 var src:Dictionary={}
class KityaraHost extends "res://scripts/lol2/jungle_walkthrough.gd":
 func _ready():pass
static func canonical(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value,"",true,true))
static func init_host(host:Node3D,tree:SceneTree):
 host.process_mode=Node.PROCESS_MODE_DISABLED
 host.item_effects=Effects.new();host.add_child(host.item_effects)
 host.interface_hud=Hud.new();host.add_child(host.interface_hud)
 if host is Host:
  host.starting_magic=Magic.new();host.add_child(host.starting_magic)
  host.act2_creatures=Population.new();host.add_child(host.act2_creatures)
 tree.root.add_child(host)
static func fill64(pack:Array):
 # Input is frozen alongside the old outcomes; a new catalog entry must not
 # silently shift every capacity-test pack (Blizzard did that before WO4).
 var seed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_grant_full_pack_seed_20c7797.json"))
 assert(seed.source_sha256==FileAccess.get_sha256("res://"+str(seed.source)),"Untouched original output baseline pins this input")
 assert(seed.ids.size()==64)
 for id in seed.ids:
  assert(Catalog.admitted(id,"jungle"))
  if pack.size()>=64:break
  if id not in pack:pack.append(id)
 assert(pack.size()==64,"capacity fixture has exactly64 original catalog identities")
static func context(name:String,variant:String,tree:SceneTree)->Dictionary:
 var host:Node3D=KityaraHost.new() if name=="kityara_knife" else Host.new()
 init_host(host,tree)
 var owner:Node
 var action:Callable
 var owner_state:Callable
 var pack:Callable=func():return host.carried_collected
 match name:
  "museum_prism":
   owner=Prism.new();action=owner.use;owner_state=func():return {"taken":owner.taken}
  "museum_aloe_rule":
   owner=Aloe.new();action=owner.use;owner_state=func():return owner.state
  "jungle_world_item":
   owner=JungleItem.new();var sprite:=Sprite3D.new();owner.add_child(sprite);owner.sprites[1]=sprite
   action=owner.collect;owner_state=func():return host.saved_quests.get(owner.KEY,owner.initial())
  "kityara_knife":
   owner=KityaraData.new();owner.src=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/jungle_kityara_source.json"));host.kityara=owner
   action=func():host._kityara_grant(int(owner.src.item.identity));return null
   owner_state=func():return {"identity":owner.src.item.identity}
  "hive_wax":
   host.carried_inventory={"collected":[]}
   owner=Wax.new();action=owner.collect;owner_state=func():return {"collected":owner.collected}
   pack=func():return host.carried_inventory.collected
  "dark_halls_loot":
   owner=DarkLoot.new();owner.source=JSON.parse_string(FileAccess.get_file_as_string(owner.SOURCE));action=owner.take
   owner_state=func():return host.saved_quests.get("dark_halls_loot",{})
  "l8_tree_slot":
   owner=TreeSlotFixture.new();var state:Dictionary=owner.initial();state.rise=2.0;state.lit=owner.TORCHES.keys();host.saved_quests[owner.KEY]=state
   var shard:="act2:L14_HT:post_shard";host.carried_collected=[shard];host.hand_item=shard;host.saved_quests.act2_items={"version":1,"collected":[shard],"carried":[shard]}
   action=func():return owner.interact("insert",shard)
   owner_state=owner.state
  "l10_priest_urn":
   owner=Priest.new();var tombs:=Tombs.new();tombs.name="L10Tombs";host.add_child(tombs)
   var bracers:="act2:L9_DR:item55";host.carried_collected=[bracers];host.saved_quests.act2_items={"version":1,"collected":[bracers],"carried":[bracers]}
   action=owner.speak
   owner_state=owner.state
  "l12_frozen_bow":
   owner=Bow.new();host.saved_quests[owner.KEY]={"version":1,"remaining":1.0,"taken":false};action=owner.take
   owner_state=owner.state
  "l14_trial_idol":
   owner=Trials.new();host.saved_quests[owner.KEY]={"version":1,"doors":["90"],"idols":[]};host.saved_quests.l14_spiral={"raised":4};action=owner.take
   owner_state=owner.state
  "l16_fountain_ball":
   owner=Ball.new();host.saved_quests[owner.KEY]={"version":1,"broken":true,"taken":[]};action=func():return owner.take(518)
   owner_state=owner.state
  "l19_horn":
   owner=Horn.new();action=owner.take
   owner_state=owner.state
  "cave_guard38_loot":
   owner=CaveLoot.new();action=owner.collect;owner_state=func():return owner.state
   pack=func():return owner.carried(owner.state)
  _:assert(false,"Missing site context "+name)
 if name!="kityara_knife":owner.host=host
 host.add_child(owner)
 if variant=="full64":fill64(host.carried_inventory.collected if name=="hive_wax" else host.carried_collected)
 return {"name":name,"variant":variant,"host":host,"owner":owner,"action":action,"owner_state":owner_state,"pack":pack}
static func snapshot(ctx:Dictionary)->Dictionary:
 var h:Node3D=ctx.host
 var saved:Dictionary=h.saved_quests if h is Host else h.quest_state
 return canonical({"pack":ctx.pack.call().duplicate(true),"quests":saved.duplicate(true),"owner":ctx.owner_state.call(),"messages":h.messages.duplicate() if h is Host else [],"journal":h.item_effects.state().get("journal",[]),"equipped_item":h.equipped_item,"equipped_armor":h.equipped_armor,"hand_item":h.hand_item,"hud_refreshes":h.interface_hud.refreshes,"presentations":h.presentations.duplicate() if h is Host else [],"sync_packets":h.sync_packets.duplicate(true) if h is Host else []})
static func run_sites(tree:SceneTree)->Dictionary:
 var cases:Dictionary={}
 for name in SITE_NAMES:
  for variant in ["normal","full64"]:
   var ctx:=context(name,variant,tree)
   var before:=snapshot(ctx);var first:Variant=ctx.action.call();var after:=snapshot(ctx)
   var second:Variant=ctx.action.call();var repeat:=snapshot(ctx)
   cases[name+":"+variant]={"before":before,"result":canonical(first),"after":after,"repeat_result":canonical(second),"repeat":repeat}
   if ctx.host is KityaraHost:
    for property in ["curse","walk_feel","player_health_owner"]:
     var node:Variant=ctx.host.get(property)
     if node is Node and is_instance_valid(node) and node.get_parent()==null:
      node.free();ctx.host.set(property,null)
   ctx.host.free()
 return cases
