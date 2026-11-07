extends Node3D
## Book-led eye switch and basin. Original command bytes do not prove the drain world effect.
const KEY="l13_eggs"
const EYE=Vector3(-3270,-26.5,4210)
const VENT=Vector3(-2171,166,4165)
const REGIONS=[322,323,324,329,330,331,332]
const DRAIN_TIME=2.0 # Explicit modern visual/physical lowering, not native byte7 speed5.
var host:Node3D
var pack:Dictionary
var materials:Dictionary={}
var doors:Node3D
var basin:Node3D
var receiver:StaticBody3D
var hint:Label
class Receiver:
 extends RefCounted
 var owner_node:Node
 func _init(node:Node):owner_node=node
 func receive_spark_level(level:int)->bool:return owner_node.break_vent(level)
static func initial()->Dictionary:return {"version":1,"eye_open":false,"vent_broken":false,"drain":0.0}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("eye_open") is bool or not s.get("vent_broken") is bool:return "Invalid citadel basin state."
 var d=s.get("drain")
 if not (d is int or d is float) or not is_finite(float(d)) or d<0 or d>DRAIN_TIME or (not s.vent_broken and d!=0):return "Invalid basin drainage."
 if s.vent_broken and not s.eye_open:return "Basin destroyed before eye access."
 for id in quests.get("act2_items",{}).get("collected",[]):
  if id in ["act2:L13_RC:item145","act2:L13_RC:item146","act2:L13_RC:item147"] and (not s.vent_broken or d!=DRAIN_TIME):return "Basin loot precedes drainage."
 return ""
static func owns(face:Dictionary)->bool:
 return (face.get("kind")=="floor" and int(face.get("region",-1)) in REGIONS) or (face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1)) in [107,108])
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_eggs.gd").new();n.host=map;n.name="L13Eggs";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 doors=Node3D.new();doors.name="OriginalIrises107108";add_child(doors)
 basin=Node3D.new();basin.name="BasinFloor";add_child(basin)
 var door_faces:Array=[];var floor_faces:Array=[]
 for face in pack.faces:
  if owns(face):
   if face.get("kind")=="floor":floor_faces.append(face)
   else:door_faces.append(face)
 build(doors,door_faces);build(basin,floor_faces)
 receiver=StaticBody3D.new();receiver.position=VENT;receiver.collision_mask=0;receiver.set_meta("spark_receiver",Receiver.new(self));add_child(receiver)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,100,24);shape.shape=box;receiver.add_child(shape)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
 restore()
func reachable()->bool:
 var delta:Vector3=EYE-host.camera.global_position
 if delta.length()>170 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.85:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,EYE,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func open_eye()->bool:
 if state().eye_open or not host.starting_magic.world_active() or host.player_form!=0 or not reachable():return false
 var s:=state().duplicate(true);s.eye_open=true;host.quest_state[KEY]=s;restore();host.save_feedback("The eye switch opens the side irises.");return true
func break_vent(level:int)->bool:
 if level not in [1,3] or not state().eye_open or state().vent_broken or not host.starting_magic.world_active():return false
 var s:=state().duplicate(true);s.vent_broken=true;host.quest_state[KEY]=s;restore();host.save_feedback("The central fixture breaks. The basin drains.");return true
func restore()->void:
 var s:=state();doors.visible=not s.eye_open;doors.get_node("Collision").collision_layer=0 if s.eye_open else 1
 for id in [107,108]:
  if host.preview_assemblies.solid_bodies.has(id):host.preview_assemblies.solid_bodies[id].collision_layer=0 if s.eye_open else 256
 basin.position.y=-20.0*float(s.drain)/DRAIN_TIME
 receiver.collision_layer=0 if s.vent_broken else 1
 for id in [265,364]:
  if host.prop_placements.has(id):
   var p:Array=host.prop_placements[id];p[0].set_instance_transform(p[1],Transform3D(Basis().scaled(Vector3.ZERO) if s.vent_broken else Basis(),p[2]))
 if is_instance_valid(host.act2_items):host.act2_items.restore()
func _physics_process(delta:float):
 if host.starting_magic.world_active() and state().vent_broken and float(state().drain)<DRAIN_TIME:
  var s:=state().duplicate(true);s.drain=minf(DRAIN_TIME,float(s.drain)+delta);host.quest_state[KEY]=s
 restore()
func _process(_delta):hint.text="E — Use eye switch" if not state().eye_open and host.starting_magic.world_active() and reachable() else ""
func _unhandled_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and open_eye():get_viewport().set_input_as_handled()

func build(parent:Node3D,faces:Array)->void:
 var groups:Dictionary={};var points:=PackedVector3Array()
 for face in faces:
  if not groups.has(face.material):
   var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);groups[face.material]=tool
  for i in [0,1,2,0,2,3]:
   var p:=Vector3(face.points[i][0],face.points[i][1],face.points[i][2]);groups[face.material].set_uv(Vector2(face.uv[i][0],face.uv[i][1]));groups[face.material].add_vertex(p);points.append(p)
 for key in groups:
  groups[key].generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=groups[key].commit()
  if not materials.has(key):
   var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[key]));mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;materials[key]=mat
  mesh.material_override=materials[key];parent.add_child(mesh)
 var body:=AnimatableBody3D.new();body.name="Collision";body.sync_to_physics=false;body.collision_mask=0
 var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body)
