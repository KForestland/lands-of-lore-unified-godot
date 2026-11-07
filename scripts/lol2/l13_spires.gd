extends Node3D
## Original Spire hit groups/locals and final selector2; modern Spark binding and instant completion.
const KEY="l13_spires"
const LOCALS={151:5,170:16,171:17,266:11,267:12,268:13,294:7,295:8,296:9,297:10,298:0,299:1,300:2,301:3,302:4,303:5,351:6}
var gate:Node3D
var ceiling:Node3D
var host:Node3D
var visuals:Dictionary={}
var aims:Dictionary={}
var receivers:Dictionary={}
class Receiver:
 extends RefCounted
 var owner_node:Node
 var id:int
 func _init(n:Node,i:int):owner_node=n;id=i
 func receive_spark_level(level:int)->bool:return owner_node.light(id,level)
static func initial()->Dictionary:return {"version":1,"lit":[]}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("lit") is Array:return "Invalid Citadel spires."
 var seen:Dictionary={}
 for id in s.lit:
  if not id is String or not id.is_valid_int() or id!=str(int(id)) or not LOCALS.has(int(id)) or seen.has(id):return "Invalid Citadel spire identity."
  seen[id]=true
 return ""
static func owns(face:Dictionary)->bool:
 return (face.get("kind")=="ceiling" and int(face.get("region",-1))==457) or (face.get("kind")=="source_wall" and int(face.get("wall_record",-1)) in [472,507])
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_spires.gd").new();n.host=map;n.name="L13Spires";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 gate=Node3D.new();gate.name="DawnGateWalls";add_child(gate)
 ceiling=Node3D.new();ceiling.name="DawnGateCeiling";add_child(ceiling)
 var walls:Array=[];var roof:Array=[]
 for face in pack.faces:
  if owns(face):
   if face.kind=="ceiling":roof.append(face)
   else:walls.append(face)
 host.get_node("L13Eggs").build(gate,walls);host.get_node("L13Eggs").build(ceiling,roof)
 var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials.prop_223));mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 for row in pack.props:
  var id:int=int(row.record)
  if not LOCALS.has(id):continue
  var p:=Vector3(row.position[0],row.position[1],row.position[2]);aims[id]=p+Vector3.UP*64
  var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(113,128);quad.center_offset=Vector3(-7.5,64,0);mesh.mesh=quad;mesh.material_override=mat;mesh.position=p;add_child(mesh);visuals[id]=mesh
  var body:=StaticBody3D.new();body.position=aims[id];body.collision_mask=0;body.set_meta("spark_receiver",Receiver.new(self,id));add_child(body)
  var box:=BoxShape3D.new();box.size=Vector3(75,110,35);var shape:=CollisionShape3D.new();shape.shape=box;body.add_child(shape);receivers[id]=body
 restore()
func light(id:int,level:int)->bool:
 if level not in [1,3] or not LOCALS.has(id) or str(id) in state().lit or not host.starting_magic.world_active() or host.player_form!=0:return false
 var s:=state().duplicate(true);s.lit.append(str(id));host.quest_state[KEY]=s;restore();host.save_feedback("The spire lights.");return true
func restore():
 if is_instance_valid(gate):
  gate.visible=not dawn_ready();gate.get_node("Collision").collision_layer=0 if dawn_ready() else 1
  ceiling.position.y=128.0 if dawn_ready() else 0.0
 for id in visuals:
  var lit:bool=str(id) in state().lit;visuals[id].visible=lit;receivers[id].collision_layer=0 if lit else 1
  var p:Array=host.prop_placements[id];p[0].set_instance_transform(p[1],Transform3D(Basis().scaled(Vector3.ZERO) if lit else Basis(),p[2]))
  if lit:host.progression.native.set_local(int(LOCALS[id]),1)
func dawn_ready()->bool:return "170" in state().lit and "171" in state().lit
