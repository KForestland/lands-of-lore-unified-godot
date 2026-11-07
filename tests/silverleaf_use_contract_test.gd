extends SceneTree
## Isolated controller contract fixture. No gameplay scene, earned item or growth claim.
const Controller=preload("res://scripts/lol2/player_item_controller.gd")
const State=preload("res://scripts/lol2/player_item_state.gd")
const Handlers=preload("res://scripts/lol2/item_handlers.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const ID="item:def117"
class Magic:
 extends Node
 var hp:=30
 var packet: Dictionary={"player":{"mana":10,"maximum":100}}
 func health()->int:return hp
 func magic_state()->Dictionary:return packet
 func commit(value: Dictionary):packet=value
class Host:
 extends Node3D
 var player_form:=0
 var carried_collected: Array=[]
 var item_effect_checkpoint: Dictionary={}
 var inventory: Control
 var starting_magic: Node
func _initialize():
 var host=Host.new();var controller=Controller.new();var magic=Magic.new()
 host.starting_magic=magic;host.inventory=Control.new()
 host.item_effect_checkpoint=State.initial();host.carried_collected=[ID]
 controller.host=host # No world scene or gameplay state is seeded by this unit fixture.
 assert(Catalog.definition(ID)==117 and Catalog.use_kind(ID)=="silverleaf")
 assert(Handlers.route(117,1).hosted and Handlers.route(117,1).handler==39)
 assert(not Handlers.route(117,5).hosted and not Handlers.route(117,16).hosted)
 host.player_form=1
 assert(not controller.use(ID) and ID in host.carried_collected and magic.packet.player.mana==10)
 host.player_form=0;magic.hp=0
 assert(not controller.use(ID) and ID in host.carried_collected)
 magic.hp=30;magic.packet.player.mana=100
 assert(not controller.use(ID) and ID in host.carried_collected and host.item_effect_checkpoint.spent.is_empty())
 magic.packet.player.mana=98
 assert(controller.use(ID) and magic.packet.player.mana==100)
 assert(ID not in host.carried_collected and host.item_effect_checkpoint.spent==[ID])
 assert(not controller.use(ID))
 assert(State.validate(host.item_effect_checkpoint,host.carried_collected).is_empty())
 var restored=State.canonical(JSON.parse_string(JSON.stringify(host.item_effect_checkpoint)))
 assert(State.validate(restored,[]).is_empty() and restored.spent==[ID])
 host.item_effect_checkpoint=State.initial();host.carried_collected=[ID];magic.packet.player.mana=10
 assert(controller.use(ID) and magic.packet.player.mana==15 and controller.last_route.handler==39)
 host.inventory.free();magic.free();controller.free();host.free()
 print("PASS Silverleaf book +5 through handler39/controller; cap, dead/form/duplicate refusal and consumed-state roundtrip. Isolated unit fixture; growth and earned acquisition unqualified.")
 quit()
