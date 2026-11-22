extends SceneTree
## Isolated controller fixture: approved no-effect protection, not an earned
## acquisition or sleeping-target claim. Original handler98 lookup is retained.
const Controller=preload("res://scripts/lol2/player_item_controller.gd")
const State=preload("res://scripts/lol2/player_item_state.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Mix=preload("res://scripts/lol2/l8_larkhon_state.gd")
class Magic:
 extends Node
 var hp:=30
 var packet: Dictionary={"player":{"mana":10,"maximum":100}}
 func health()->int:return hp
 func magic_state()->Dictionary:return packet
class Host:
 extends Node3D
 var player_form:=0
 var carried_collected: Array=[]
 var item_effect_checkpoint: Dictionary={}
 var inventory: Control
 var starting_magic: Node
 var messages:Array=[]
 func save_feedback(line:String):messages.append(line)
func _initialize():
 for id in ["item:def119","act2:L8_SJ:item26","act2:L8_SJ:shaman_amaranth"]:
  var host=Host.new();var controller=Controller.new();var magic=Magic.new()
  host.starting_magic=magic;host.inventory=Control.new();host.item_effect_checkpoint=State.initial();host.carried_collected=[id]
  controller.host=host
  assert(Catalog.definition(id)==119 and Catalog.use_kind(id)=="amaranth_serum")
  assert(controller.Handlers.route(119,1).hosted and controller.Handlers.route(119,1).handler==98)
  host.player_form=1;assert(not controller.use(id) and id in host.carried_collected)
  host.player_form=0;magic.hp=0;assert(not controller.use(id) and id in host.carried_collected)
  magic.hp=30;var before: Dictionary=magic.packet.duplicate(true)
  var effects:Dictionary=host.item_effect_checkpoint.duplicate(true);host.messages.clear()
  assert(not controller.use(id) and magic.hp==30 and magic.packet==before)
  assert(host.carried_collected==[id] and host.item_effect_checkpoint==effects and host.messages==[Controller.SERUM_REFUSAL])
  assert(not controller.use(id) and host.carried_collected==[id] and host.item_effect_checkpoint==effects)
  assert(host.messages==[Controller.SERUM_REFUSAL,Controller.SERUM_REFUSAL] and not controller.use("wrong"))
  assert(State.validate(host.item_effect_checkpoint,host.carried_collected).is_empty())
  var restored:=State.canonical(JSON.parse_string(JSON.stringify(host.item_effect_checkpoint)))
  assert(restored.spent.is_empty() and State.validate(restored,host.carried_collected).is_empty())
  # Generic world ids are controller-only fixtures, not save-admitted pickups.
  # The two actual Act2 identities remain accepted by the unchanged recipe.
  if Mix.Items.valid(id):
   var leaf:String="act2:L10_DC:silverleaf159"
   var ingredients:Array=[id,leaf]
   var result:Dictionary=Mix.mix(Mix.initial(),ingredients,leaf,id)
   assert(result.ok and result.inventory==[Mix.VAPORS] and Mix.mixed(result.state) and ingredients==[id,leaf])
  host.inventory.free();magic.free();controller.free();host.free()
 print("PASS all three amaranth identities retain the item with mixing hint/no HP or mana effect/no spent receipt, repeat/form/dead/missing/JSON checks; original handler98 lookup and pure recipe remain valid; acquisition/target unqualified")
 quit()
