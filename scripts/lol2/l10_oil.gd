extends Node3D
## Prima101-102: book-led ignition/collapse. Original source words select the scoped geometry;
## mana/range/blast, clipping and persistence are explicit modern adapters.
const KEY:="l10_oil"
const AIM:=Vector3(-1443,12,-3307)
const BLAST_RADIUS:=240.0
const BLAST_DAMAGE:=20
static var cached: Dictionary={}
var host: Node3D
var intact: Node3D
var collapsed: Node3D
var receiver: StaticBody3D
var presented: Variant=null
var flash: MeshInstance3D
var flash_time:=0.0
var materials: Dictionary={}
class Receiver:
 extends RefCounted
 var node: Node
 func _init(owner_node: Node):node=owner_node
 func receive_spark()->bool:return node.ignite(1)
 func receive_spark_level(level: int)->bool:return node.ignite(level)
static func source()->Dictionary:
 if cached.is_empty():
  cached=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l10_oil_source.json"))
  for key in ["floors","lower_ceilings","removed_controls"]:
   var ids:={}
   for n in cached[key]:ids[int(n)]=true
   cached[key]=ids
 return cached
static func owns(face: Dictionary)->bool:
 var src:=source();var region:=int(face.get("region",-1)) if face.get("region")!=null else -1
 return (face.kind=="floor" and src.floors.has(region)) or (face.kind=="ceiling" and src.lower_ceilings.has(region)) or (face.get("placement_kind")=="static_assembly" and src.removed_controls.has(int(face.get("source_index",-1))))
static func validate(s: Variant)->String:
 return "" if s is Dictionary and s.size()==2 and s.get("version")==1 and s.get("burned") is bool else "Invalid Cemetery oil state."
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_oil.gd").new();node.host=map;node.name="L10Oil";map.add_child(node);return node
func burned()->bool:return host.quest_state.get(KEY,{}).get("burned",false)
func polygon(face: Dictionary)->PackedVector2Array:
 var points:=PackedVector2Array()
 for p in face.points:points.append(Vector2(p[0],p[2]))
 return points
func _ready():
 intact=Node3D.new();intact.name="IntactTomb";add_child(intact)
 collapsed=Node3D.new();collapsed.name="RemainingCeiling";add_child(collapsed)
 var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 var holes: Array=[]
 for face in pack.faces:
  if face.kind=="floor" and source().floors.has(int(face.region)):holes.append(polygon(face))
 var before: Array=[];var after: Array=[]
 for face in pack.faces:
  if not owns(face):continue
  before.append(face)
  if face.kind!="ceiling":continue
  var parts: Array=[polygon(face)]
  for hole in holes:
   var next: Array=[]
   for part in parts:next.append_array(Geometry2D.clip_polygons(part,hole))
   parts=next
  for part in parts:
   if part.size()<3:continue
   var row: Dictionary=face.duplicate(true);row.points=[];row.uv=[]
   var origin:=Vector2(face.points[0][0],face.points[0][2])
   var u:=Vector2(face.points[1][0],face.points[1][2])-origin
   var v:=Vector2(face.points[3][0],face.points[3][2])-origin
   var det:=u.cross(v)
   for point in part:
    row.points.append([point.x,face.points[0][1],point.y])
    var offset: Vector2=point-origin
    var a: float=offset.cross(v)/det if absf(det)>0.0001 else 0
    var b: float=u.cross(offset)/det if absf(det)>0.0001 else 0
    var uv:=Vector2(face.uv[0][0],face.uv[0][1])+a*(Vector2(face.uv[1][0],face.uv[1][1])-Vector2(face.uv[0][0],face.uv[0][1]))+b*(Vector2(face.uv[3][0],face.uv[3][1])-Vector2(face.uv[0][0],face.uv[0][1]))
    row.uv.append([uv.x,uv.y])
   after.append(row)
 build(intact,before,pack);build(collapsed,after,pack)
 receiver=StaticBody3D.new();receiver.position=AIM;receiver.collision_layer=1;receiver.collision_mask=0
 receiver.set_meta("spark_receiver",Receiver.new(self))
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(36,24,14);shape.shape=box;receiver.add_child(shape);add_child(receiver)
 flash=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=BLAST_RADIUS;sphere.height=BLAST_RADIUS*2;flash.mesh=sphere;flash.position=AIM
 var material:=StandardMaterial3D.new();material.albedo_color=Color(1,0.3,0.02,0.28);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;flash.material_override=material;add_child(flash);flash.visible=false
 restore()
func build(parent: Node3D,faces: Array,pack: Dictionary):
 var groups:={};var collision:=PackedVector3Array()
 for face in faces:
  var indices: PackedInt32Array
  if face.points.size()==4:indices=PackedInt32Array([0,1,2,0,2,3])
  else:indices=Geometry2D.triangulate_polygon(polygon(face))
  if not groups.has(face.material):
   var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);groups[face.material]=surface
  for i in indices:
   var point:=Vector3(face.points[i][0],face.points[i][1],face.points[i][2])
   groups[face.material].set_uv(Vector2(face.uv[i][0],face.uv[i][1]));groups[face.material].add_vertex(point);collision.append(point)
 for key in groups:
  groups[key].generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=groups[key].commit()
  if not materials.has(key):
   var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[key]));material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;materials[key]=material
  mesh.material_override=materials[key];parent.add_child(mesh)
 var body:=StaticBody3D.new();body.name="Collision";body.collision_mask=0;parent.add_child(body)
 if not collision.is_empty():
  var shape:=CollisionShape3D.new();var triangles:=ConcavePolygonShape3D.new();triangles.backface_collision=true;triangles.set_faces(collision);shape.shape=triangles;body.add_child(shape)
func restore():
 var value:=burned()
 receiver.collision_layer=1 if not value and host.get_node("L10Barrel").state().phase==2 else 0
 if presented==value:return
 presented=value;intact.visible=not value;collapsed.visible=value
 intact.get_node("Collision").collision_layer=0 if value else 1
 collapsed.get_node("Collision").collision_layer=1 if value else 0
 for id in source().removed_controls:
  if host.preview_assemblies.solid_bodies.has(id):host.preview_assemblies.solid_bodies[id].collision_layer=0 if value else 256
func ignite(level: int)->bool:
 if level not in [1,3,5] or burned() or host.get_node("L10Barrel").state().phase!=2 or not host.starting_magic.world_active():return false
 host.quest_state[KEY]={"version":1,"burned":true};restore()
 # Damage precedes the geometry change's next physics frame; a close caster is caught in the blast.
 if host.player.global_position.distance_to(AIM)<BLAST_RADIUS and not host.starting_magic.protected():host.starting_magic.set_health(maxi(0,host.starting_magic.health()-BLAST_DAMAGE))
 flash_time=0.5;host.save_feedback("The oil explodes. The tomb floor collapses into the catacombs.")
 return true
func _process(delta):
 restore()
 if host.starting_magic.world_active():flash_time=maxf(0,flash_time-delta)
 flash.visible=flash_time>0
