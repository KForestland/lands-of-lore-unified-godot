extends Node3D
## Prima's at-will form choice at this stage; contextual adapter until curse-control UI is hosted.
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
const ENTRANCE=Vector3(3000,-1058,-13600)
const GROTTO=Vector3(3300,-1078,-14530)
var host:Node3D
var hint:Label
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
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,435);canvas.add_child(hint)
func reachable()->bool:
 if not host.starting_magic.world_active() or "act2:L13_RC:dreamstone" not in host.carried_collected:return false
 return host.player.position.distance_to(ENTRANCE)<180 or host.player.position.distance_to(GROTTO)<180
func choose_form()->bool:
 if not reachable() or host.curse.state.phase in [1,3]:return false
 return host.curse.request_timed_form(2,60.0) if host.player_form==0 else host.curse.request_human() if host.player_form==2 else false
func _process(_delta):hint.text=("E — Change to Lizard for the crevasse" if host.player_form==0 else "E — Return to Human" if host.player_form==2 else "") if reachable() else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and choose_form():get_viewport().set_input_as_handled()

func restore():
 if not is_instance_valid(gate):return
 gate.visible=not state().opened;gate.get_node("Collision").collision_layer=0 if state().opened else 1
 if host.preview_assemblies.solid_bodies.has(91):host.preview_assemblies.solid_bodies[91].collision_layer=0
func spark(level:int)->bool:
 if level not in [1,3] or state().opened or host.player_form!=0 or not host.starting_magic.world_active():return false
 host.quest_state[KEY]={"version":1,"opened":true};restore();host.save_feedback("The rocks clear from the crevasse.");return true
