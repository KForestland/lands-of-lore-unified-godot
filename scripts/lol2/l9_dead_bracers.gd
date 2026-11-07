extends Node3D
## Prima113: Spark the niche shield after the larger Saar. Source shield312/item55.
var host: Node3D
var barrier: StaticBody3D
var panel: Node3D
var aim:=Vector3(-3754,455,-816)
class Receiver:
 extends RefCounted
 var owner_node: Node
 func _init(node: Node):owner_node=node
 func receive_spark()->bool:return owner_node.release()
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_dead_bracers.gd").new()
 node.host=map;node.name="L9DeadBracers";map.add_child(node);return node
static func validate(value: Variant)->String:
 if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("released") is bool:return "Invalid bracers shield state."
 return ""
func released()->bool:return host.quest_state.get("l9_dead_bracers",{}).get("released",false)
func _ready():
 panel=Node3D.new();add_child(panel)
 barrier=StaticBody3D.new();barrier.collision_mask=0;barrier.set_meta("spark_receiver",Receiver.new(self));add_child(barrier)
 var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 var collision:=PackedVector3Array()
 var materials: Dictionary={}
 for face in pack.faces:
  if face.get("placement_kind")!="static_assembly" or int(face.get("source_index",-1))!=312:continue
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in [0,1,2,0,2,3]:
   var point:=Vector3(face.points[i][0],face.points[i][1],face.points[i][2])
   surface.set_uv(Vector2(face.uv[i][0],face.uv[i][1]));surface.add_vertex(point);collision.append(point)
  surface.generate_normals()
  if not materials.has(face.material):
   var material:=StandardMaterial3D.new()
   material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[face.material]))
   material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
   materials[face.material]=material
  var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=materials[face.material];panel.add_child(mesh)
 var shape:=CollisionShape3D.new();var polygon:=ConcavePolygonShape3D.new();polygon.backface_collision=true;polygon.set_faces(collision)
 shape.shape=polygon;barrier.add_child(shape);restore()
func release()->bool:
 if released() or host.act2_creatures.state.actors["79"].health>0:return false
 host.quest_state.l9_dead_bracers={"version":1,"released":true};restore();host.save_feedback("The shield around the bracers fades.");return true
func restore():
 panel.visible=not released();barrier.collision_layer=0 if released() else 1
func _process(_delta):restore()
