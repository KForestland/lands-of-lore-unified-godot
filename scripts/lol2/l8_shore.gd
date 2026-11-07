extends Node
## Earned shore arrival and lasting Ruins closure; modern presentation/receipt.
const KEY:="l8_shore"
var host:Node3D
static func initial()->Dictionary:return {"version":1,"arrived":false}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("arrived") is bool:return "Invalid Savage Jungle shore receipt."
 return ""
static func closed(quests:Dictionary)->bool:return quests.get(KEY,{}).get("arrived",false)
static func attach(map:Node3D)->Node:
 var node=load("res://scripts/lol2/l8_shore.gd").new();node.host=map;node.name="L8Shore";map.add_child(node);return node
func _ready():
 if closed(host.quest_state):return
 if not host.arrived_by_level_change or host.start_selector!=5 or not host.quest_state.get("l9_escape",{}).get("escaped",false):return
 # Source prop630 kind6/value20/extra05 group7888 links original Dawn20.
 # This owner applies that one known consequence after the earned exit, not the unhosted group.
 host.act2_creatures.State.spawn(host.act2_creatures.state,"20")
 host.act2_creatures.sync_quests();host.act2_creatures.present()
 host.quest_state[KEY]={"version":1,"arrived":true}
 host.save_feedback("You wake on the Savage Jungle shore. Dawn is nearby. The flooded ruins are closed.")
