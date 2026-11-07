extends Node3D
const State=preload("res://scripts/lol2/l12_glacier_state.gd")
var host:Node3D
var floor_root:Node3D
var logs:Node3D
var upper_shape:ConcavePolygonShape3D
var materials:Dictionary={}
var pack:Dictionary={}
static func owns(face:Dictionary)->bool:
 return (face.get("kind")=="floor" and int(face.get("region",-1))>=919 and int(face.get("region",-1))<=930) or (face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1)) in [52,53,54,55,56,57])
static func owns_upper(face:Dictionary)->bool:return face.get("kind")=="floor" and int(face.get("region",-1)) in [914,915]
static func attach(map:Node3D)->Node:
 var node=load("res://scripts/lol2/l12_glacier.gd").new();node.host=map;node.name="L12Glacier";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 floor_root=Node3D.new();floor_root.name="MovingGlacierFloors";add_child(floor_root)
 logs=Node3D.new();logs.name="SourceRemovedLogs";add_child(logs)
 var floor_faces:Array=[];var log_faces:Array=[]
 for face in pack.faces:
  if owns(face):
   if face.get("kind")=="floor":floor_faces.append(face)
   else:log_faces.append(face)
 build(floor_root,floor_faces);build(logs,log_faces)
 var upper:=StaticBody3D.new();upper.name="OriginalUpperReturnFloors";upper.collision_mask=0;add_child(upper)
 var points:=PackedVector3Array()
 for face in pack.faces:
  if owns_upper(face):
   for i in [0,1,2,0,2,3]:points.append(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
 upper_shape=ConcavePolygonShape3D.new();upper_shape.set_faces(points)
 var shape:=CollisionShape3D.new();shape.shape=upper_shape;upper.add_child(shape);restore()
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
func restore()->void:
 floor_root.position.y=float(state().motion.height)+590
 var exited:=preload("res://scripts/lol2/l13_exit_lock_state.gd").unlocked(host.quest_state.get("l13_exit_lock",preload("res://scripts/lol2/l13_exit_lock_state.gd").initial()))
 upper_shape.backface_collision=not exited
 var removed:bool=state().started and not exited
 logs.visible=not removed;logs.get_node("Collision").collision_layer=0 if removed else 1
 for id in [52,53,54,55,56,57]:
  if host.preview_assemblies.solid_bodies.has(id):host.preview_assemblies.solid_bodies[id].collision_layer=0 if removed else 256
func _physics_process(delta:float)->void:
 if host.starting_magic.world_active():
  var s:=state().duplicate(true)
  # Book-led first-entry trigger. Native prop335 kind2/kind6 dispatch remains unjoined.
  if not s.started and host.progression.region_at(host.player.position) in [932,916]:
   if State.start(s):host.save_feedback("The glacier gives way. Keep to the right-hand wall.")
  State.advance(s,delta)
  if s.started:host.quest_state[State.KEY]=s
 restore()
