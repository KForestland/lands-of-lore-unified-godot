extends Node3D
const RESTORE_ON := ["load"]
## Original rock gate; form choice belongs to the shared learned Curse spells.
const KEY="l12_crevasse"
const SPARK=Vector3(3052,-1050,-13628)
var gate:Node3D
class Receiver:
 extends RefCounted
 var owner:Node
 func _init(n:Node):owner=n
 func receive_spark_level(level:int)->bool:return owner.spark(level)
static func initial()->Dictionary:return {"version":1,"opened":false}
static func validate(s:Variant)->String:
 return "" if s is Dictionary and s.size()==2 and s.get("version")==1 and s.get("opened") is bool else "Invalid crevasse gate."
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))==91
func state()->Dictionary:return host.quest_state.get(KEY,initial())
var host:Node3D
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l12_crevasse.gd").new();n.host=map;n.name="L12Crevasse";map.add_child(n);return n
func _ready():
 gate=Node3D.new();gate.name="OriginalAvalanche91";add_child(gate)
 var faces:Array=[]
 for f in JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file)).faces:
  if owns(f):faces.append(f)
 host.get_node("L12Glacier").build(gate,faces)
 var body:=StaticBody3D.new();body.position=SPARK;body.collision_mask=0;body.set_meta("spark_receiver",Receiver.new(self));add_child(body)
 var box:=BoxShape3D.new();box.size=Vector3(24,48,24);var shape:=CollisionShape3D.new();shape.shape=box;body.add_child(shape)
 restore()

func restore():
 if not is_instance_valid(gate):return
 gate.visible=not state().opened;gate.get_node("Collision").collision_layer=0 if state().opened else 1
 if host.preview_assemblies.solid_bodies.has(91):host.preview_assemblies.solid_bodies[91].collision_layer=0
func spark(level:int)->bool:
 if level not in [1,3] or state().opened or host.player_form!=0 or not host.starting_magic.world_active():return false
 host.quest_state[KEY]={"version":1,"opened":true};restore();host.save_feedback("The rocks clear from the crevasse.");return true

## Modern chain teaching before the chosen-lizard crevasse, at its existing
## rock anchor. Three-dimensional reach excludes unrelated stacked rooms.
func needs_shape_lesson()->bool:
 return host.player.global_position.distance_to(SPARK)<256.0
