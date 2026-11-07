extends SceneTree
## Isolated controller fixture: not an earned item, mixing or sleeping-target claim.
const Controller=preload("res://scripts/lol2/player_item_controller.gd")
const State=preload("res://scripts/lol2/player_item_state.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
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
func _initialize():
 for id in ["item:def119","act2:L8_SJ:item26"]:
  var host=Host.new();var controller=Controller.new();var magic=Magic.new()
  host.starting_magic=magic;host.inventory=Control.new();host.item_effect_checkpoint=State.initial();host.carried_collected=[id]
  controller.host=host
  assert(Catalog.definition(id)==119 and Catalog.use_kind(id)=="amaranth_serum")
  assert(controller.Handlers.route(119,1).hosted and controller.Handlers.route(119,1).handler==98)
  host.player_form=1;assert(not controller.use(id) and id in host.carried_collected)
  host.player_form=0;magic.hp=0;assert(not controller.use(id) and id in host.carried_collected)
  magic.hp=30;var before: Dictionary=magic.packet.duplicate(true)
  assert(controller.use(id) and magic.hp==30 and magic.packet==before)
  assert(id not in host.carried_collected and host.item_effect_checkpoint.spent==[id] and controller.last_route.handler==98)
  assert(not controller.use(id) and not controller.use("wrong"))
  assert(State.validate(host.item_effect_checkpoint,host.carried_collected).is_empty())
  var restored:=State.canonical(JSON.parse_string(JSON.stringify(host.item_effect_checkpoint)))
  assert(restored.spent==[id] and State.validate(restored,[]).is_empty())
  host.inventory.free();magic.free();controller.free();host.free()
 print("PASS amaranth definition119/handler98 consumes once without health/mana effect; form/dead/missing/duplicate and consumed-state roundtrip; isolated fixture, mixing/acquisition unqualified")
 quit()
