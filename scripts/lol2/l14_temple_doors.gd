extends Node3D
const State=preload("res://scripts/lol2/l8_temple_door_state.gd")
var host:Node3D
var gate:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [92,93]
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_temple_doors.gd").new();n.host=map;n.name="L14TempleDoors";map.add_child(n);return n
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 gate=Node3D.new();gate.name="OriginalMainDoors92And93";add_child(gate)
 var faces:Array=[]
 for f in pack.faces:
  if owns(f):faces.append(f)
 build(gate,faces);restore()
func restore():
 if not is_instance_valid(gate):return
 var opened:=State.unlocked(host.quest_state.get(State.KEY,State.initial()))
 gate.visible=not opened;gate.get_node("Collision").collision_layer=0 if opened else 1
func _physics_process(_delta):restore()
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
