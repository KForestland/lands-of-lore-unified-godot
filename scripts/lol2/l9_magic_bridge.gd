extends Node3D
## Source prop2648/group13448 -> Magic Bridge466/467; immediate selector7 is a modern adapter.
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
const AIM:=Vector3(-1193,28,-1943)
var host: Node3D
var bodies: Array=[]
var presented:=false
class Receiver:
 extends RefCounted
 var owner_node: Node
 func _init(node: Node):owner_node=node
 func receive_spark()->bool:return owner_node.activate()
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_magic_bridge.gd").new()
 node.host=map;node.name="L9MagicBridge";map.add_child(node);return node
static func validate(value: Variant)->String:
 if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("raised") is bool:return "Invalid magic bridge state."
 return ""
func raised()->bool:return host.quest_state.get("l9_magic_bridge",{}).get("raised",false)
func _ready():
 var receiver:=StaticBody3D.new();receiver.collision_layer=1;receiver.collision_mask=0
 receiver.position=AIM;receiver.set_meta("spark_receiver",Receiver.new(self))
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(26,57,12);shape.shape=box
 receiver.add_child(shape);add_child(receiver)
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L9_DR.json"))
 for id in [466,467]:
  var box_source: Dictionary=source.boxes[str(id)].duplicate(true)
  for child in box_source.children:child.mask=1 if int(child.mask)&(1<<7) else 0
  var body=Assemblies.box_body(id,box_source,Vector3.ZERO,true)
  add_child(body);bodies.append(body)
  # The generic host draws no initial faces for these selector0 assemblies.
  host.preview_assemblies.stateful_meshes[id]=[]
 host.player.collision_mask|=Assemblies.SCENERY_LAYER
 restore(true)
func activate()->bool:
 if raised():return false
 host.quest_state.l9_magic_bridge={"version":1,"raised":true}
 restore();host.save_feedback("The magic bridge rises.");return true
func restore(force: bool=false):
 var value:=raised()
 if not force and value==presented:return
 presented=value
 for id in [466,467]:host.preview_assemblies.set_mode(id,7 if value else 0)
 for body in bodies:body.collision_layer=Assemblies.SCENERY_LAYER if value else 0
func _process(_delta):restore()
