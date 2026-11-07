extends Node3D
## Original prop420 / control106 / region1226; modern Spark-to-use and instant opening.
const KEY="l13_egg_door"
const AIM=Vector3(-3254,43.5,5330)
const Blockers=preload("res://scripts/lol2/region_blockers.gd")
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
var host:Node3D
var blocker:Node
var renderer:Node3D
var face_body:StaticBody3D
var receiver:StaticBody3D
var presented:Variant=null
class Receiver:
 extends RefCounted
 var owner_node:Node
 func _init(node:Node):owner_node=node
 func receive_spark_level(level:int)->bool:return owner_node.light(level)
static func initial()->Dictionary:return {"version":1,"opened":false}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("opened") is bool:return "Invalid egg-chamber door."
 return ""
static func owns(face:Dictionary)->bool:return face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1))==106
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_egg_door.gd").new();n.host=map;n.name="L13EggDoor";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 renderer=Assemblies.new();renderer.host=host;renderer.data=JSON.parse_string(FileAccess.get_file_as_string(Assemblies.ROOT+"L13_RC/assemblies.json"));add_child(renderer)
 var faces:Array=[];var points:=PackedVector3Array()
 for face in renderer.data.faces:
  if int(face.assembly)!=106 or not face.initial:continue
  faces.append(face)
  for i in [0,1,2,0,2,3]:points.append(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
 renderer._build_assembly(106,faces)
 face_body=StaticBody3D.new();face_body.collision_mask=0;add_child(face_body)
 var shape:=CollisionShape3D.new();var triangle:=ConcavePolygonShape3D.new();triangle.backface_collision=true;triangle.set_faces(points);shape.shape=triangle;face_body.add_child(shape)
 blocker=host.get_node("RegionBlockers")
 receiver=StaticBody3D.new();receiver.position=AIM;receiver.collision_layer=1;receiver.collision_mask=0;receiver.set_meta("spark_receiver",Receiver.new(self));add_child(receiver)
 var hit_shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=24;hit_shape.shape=sphere;receiver.add_child(hit_shape)
 restore()
func light(level:int)->bool:
 if level not in [1,3] or state().opened or not host.starting_magic.world_active() or host.player_form!=0:return false
 # The production ray admits this callback; mana and cooldown belong to PlayerStartingMagic.
 host.quest_state[KEY]={"version":1,"opened":true};restore();host.save_feedback("The globe lights. The egg-chamber door opens.");return true
func restore()->void:
 var opened:bool=state().opened
 if presented==opened:return
 presented=opened;renderer.visible=not opened;face_body.collision_layer=0 if opened else 1
 if host.preview_assemblies.solid_bodies.has(106):host.preview_assemblies.solid_bodies[106].collision_layer=0 if opened else 256
 blocker.set_region_blocked(1226,not opened)
func _process(_delta):restore()
