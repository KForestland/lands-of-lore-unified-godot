extends "res://scripts/lol2/l13_eggs.gd"
## Source floor endpoints; book-led Spark/nearby E trigger and modern 60 Hz clock/carry.
const LIFT_KEY="l13_elevator"
const Motion=preload("res://scripts/lol2/floor_motion_step.gd")
const FLOORS=[147,148,149,153,154,159,163]
const BRAIN=Vector3(-4781,24,2981)
var landing_gate:Node3D
var deck:Node3D
var brain_receiver:StaticBody3D
class BrainReceiver:
 extends RefCounted
 var lift:Node
 func _init(node:Node):lift=node
 func receive_spark_level(level:int)->bool:return lift.activate(level)
static func lift_initial()->Dictionary:return {"version":1,"started":false,"clock":0.0,"motion":{"height":-40,"remaining":0,"fraction":0,"speed":60}}
static func validate_lift(s:Variant)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("started") is bool:return "Invalid citadel elevator."
 if not Motion.valid(s.get("motion")) or s.motion.size()!=4 or s.motion.speed!=60:return "Invalid citadel elevator motion."
 var c=s.get("clock")
 if not (c is int or c is float) or not is_finite(float(c)) or c<0 or c>=1:return "Invalid elevator clock."
 if not s.started:
  if s.motion.height!=-40 or s.motion.remaining!=0 or s.motion.fraction!=0 or c!=0:return "Changed inactive elevator."
 elif s.motion.height< -1040 or s.motion.height> -40 or int(s.motion.height+s.motion.remaining) not in [-1040,-40]:return "Invalid elevator target."
 return ""
static func owns_lift(face:Dictionary)->bool:return (face.get("kind")=="floor" and int(face.get("region",-1)) in FLOORS) or (face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1))==102)
static func attach_lift(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_elevator.gd").new();n.host=map;n.name="L13Elevator";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(LIFT_KEY,lift_initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 deck=Node3D.new();deck.name="OriginalElevatorFloors";add_child(deck)
 var faces:Array=[];var gate_faces:Array=[]
 for f in pack.faces:
  if owns_lift(f):
   if f.get("kind")=="floor":faces.append(f)
   else:gate_faces.append(f)
 build(deck,faces)
 landing_gate=Node3D.new();landing_gate.name="OriginalLandingGate102";add_child(landing_gate);build(landing_gate,gate_faces)
 brain_receiver=StaticBody3D.new();brain_receiver.position=BRAIN;brain_receiver.collision_mask=0;brain_receiver.set_meta("spark_receiver",BrainReceiver.new(self));deck.add_child(brain_receiver)
 var box:=BoxShape3D.new();box.size=Vector3(70,80,70);var shape:=CollisionShape3D.new();shape.shape=box;brain_receiver.add_child(shape)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,480);canvas.add_child(hint)
 restore()
func aim()->Vector3:return BRAIN+Vector3.UP*(float(state().motion.height)+40)
func reachable()->bool:
 var d:Vector3=aim()-host.camera.global_position
 if d.length()>170 or d.length()<0.01 or (-host.camera.global_basis.z).dot(d.normalized())<0.85:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,aim(),1,[host.player.get_rid(),brain_receiver.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func upper_call_reachable()->bool:
 if host.player_form!=0 or not host.starting_magic.world_active() or state().motion.height!=-1040 or state().motion.remaining!=0:return false
 var d:Vector3=BRAIN-host.camera.global_position
 return d.length()<360 and (-host.camera.global_basis.z).dot(d.normalized())>0.85 and host.player.is_on_floor() and host.player.position.y> -60
func call_upper()->bool:
 if not upper_call_reachable():return false
 return activate()
func activate(level:int=1)->bool:
 if level not in [1,3] or state().motion.remaining!=0 or host.player_form!=0 or not host.starting_magic.world_active():return false
 var s:=state().duplicate(true);s.started=true;s.clock=0.0;s.motion.fraction=0
 s.motion.remaining=1000 if s.motion.height==-1040 else -1000
 host.quest_state[LIFT_KEY]=s;host.save_feedback("The elevator rises." if s.motion.remaining>0 else "The elevator descends.");return true
func restore()->void:
 deck.position.y=float(state().motion.height)+40
 var opened:bool=state().started and state().motion.height==-1040
 landing_gate.visible=not opened;landing_gate.get_node("Collision").collision_layer=0 if opened else 1
 if host.preview_assemblies.solid_bodies.has(102):host.preview_assemblies.solid_bodies[102].collision_layer=0 if opened else 256
 if host.prop_placements.has(362):
  var p:Array=host.prop_placements[362];p[0].set_instance_transform(p[1],Transform3D(Basis(),p[2]+Vector3.UP*deck.position.y))
func _physics_process(delta:float):
 if host.starting_magic.world_active() and state().started and state().motion.remaining!=0:
  var riding:=false
  var p:Vector3=host.player.global_position
  var ray:=PhysicsRayQueryParameters3D.create(p,p-Vector3.UP*64,1,[host.player.get_rid()])
  var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
  riding=not hit.is_empty() and hit.collider==deck.get_node("Collision") and absf(p.y-32-float(state().motion.height))<6
  var s:=state().duplicate(true);var old:float=s.motion.height;s.clock=float(s.clock)+delta*60
  while s.clock>=1:
   s.clock-=1;Motion.advance_one(s.motion,65536)
  host.quest_state[LIFT_KEY]=s;restore()
  if riding:host.player.position.y+=float(s.motion.height)-old
func _process(_delta):hint.text="E — Call elevator" if upper_call_reachable() else "E — Use elevator brain" if state().motion.remaining==0 and host.starting_magic.world_active() and reachable() else ""
func _unhandled_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and (call_upper() or (reachable() and activate())):get_viewport().set_input_as_handled()
