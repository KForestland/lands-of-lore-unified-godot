extends Node3D
## Book-led Spark door and mirror-room alcoves; opcode18 player movement remains untraced.
const AIM:=Vector3(-1888,28,-1267)
const SOURCE="res://scripts/lol2/l9_mirror_source.json"
var host: Node3D
var source: Dictionary
var presented: Variant=null
var cooldown:=0.0
var transports: Array=[]
class Receiver:
 extends RefCounted
 var owner_node: Node
 func _init(node: Node):owner_node=node
 func receive_spark()->bool:return owner_node.open()
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_mirrors.gd").new()
 node.host=map;node.name="L9Mirrors";map.add_child(node);return node
static func validate(value: Variant)->String:
 if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("opened") is bool:return "Invalid mirror door state."
 return ""
func opened()->bool:return host.quest_state.get("l9_mirrors",{}).get("opened",false)
func _ready():
 source=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 var receiver:=StaticBody3D.new();receiver.position=AIM;receiver.collision_layer=1;receiver.collision_mask=0
 receiver.set_meta("spark_receiver",Receiver.new(self))
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(26,57,12);shape.shape=box
 receiver.add_child(shape);add_child(receiver);restore()
func open()->bool:
 if opened():return false
 host.quest_state.l9_mirrors={"version":1,"opened":true};restore();host.save_feedback("The mirror-room doors open.");return true
func restore():
 if presented==opened():return
 presented=opened()
 # Reuse the source movable geometry/motion owner without replaying source groups8602/8620.
 for id in [65,66]:
  host.progression.travel[id]=int(host.progression.native.attributes["movable:%d"%id].angle_word) if opened() else 0
  host.progression._pose(id)
func _process(_delta):restore()
func _physics_process(delta: float):
 cooldown=maxf(0,cooldown-delta)
 if cooldown>0 or get_tree().paused or host.flying or not host.starting_magic.world_active():return
 var feet: float=host.player.position.y-32
 for entry in source.transports:
  if entry.requires_open and not opened():continue
  for region in entry.regions:
   var row: Array=host.progression.regions[int(region)]
   if absf(feet-float(row[1]))>40 or not touches(int(region)):continue
   var p: Array=entry.position;var landing:=Vector3(p[0],p[1],p[2])
   # Ground on the unique destination source floor; opcode18's height word is NOT decoded here.
   host.player.position=landing;host.player.velocity=Vector3.ZERO
   host.player.rotation.y=-TAU*float(entry.heading)/65536;host.camera.rotation.x=0
   host.progression.enter_region(host.progression.region_at(landing))
   transports.append({"region":int(region),"position":p.duplicate()});cooldown=0.5;return

func touches(region: int)->bool:
 if host.progression._inside(region,host.player.position):return true
 var point:=Vector2(host.player.position.x,host.player.position.z)
 var polygon: Array=host.progression.regions[region][0]
 var radius: float=host.player.get_child(0).shape.radius
 for i in polygon.size():
  var a:=Vector2(polygon[i][0],polygon[i][1]);var next: Array=polygon[(i+1)%polygon.size()]
  var b:=Vector2(next[0],next[1])
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))<=radius:return true
 return false
