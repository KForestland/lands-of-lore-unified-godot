extends Node3D
const KEY="l14_bedroom"
const POINT=Vector3(2245,145,-5209)
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
var host:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var panels:Array[Node3D]=[]
var hint:Label
static func initial()->Dictionary:return {"version":1,"headboard":false,"elapsed":0.0}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("headboard") is bool:return "Invalid Temple bedroom."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("elapsed")) or not is_finite(s.elapsed) or s.elapsed<0 or s.elapsed>2:return "Invalid bedroom timing."
 if not s.headboard and s.elapsed!=0:return "Inactive bedroom timing."
 if s.headboard and not quests.get("l14_hanging",{}).get("opened",false):return "Bedroom lacks opened passage."
 return ""
static func owns(f:Dictionary)->bool:
 return (f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [0,1]) or (f.get("kind")=="ceiling" and int(f.get("region",-1))==2358)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_bedroom.gd").new();n.host=map;n.name="L14Bedroom";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in [0,1,2358]:
  var node:=Node3D.new();node.name="OriginalHeadboard"+str(id) if id!=2358 else "OriginalCrackCeiling2358";add_child(node)
  var faces:Array=[]
  for f in pack.faces:
   if owns(f) and (f.get("region")==id if id==2358 else f.get("source_index")==id):faces.append(f)
  build(node,faces)
  if id!=2358:panels.append(node)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable()->bool:
 if host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=POINT-host.camera.global_position
 return d.length()>0.01 and d.length()<145 and (-host.camera.global_basis.z).dot(d.normalized())>0.9
func interact()->Dictionary:
 if not reachable():return Kit.refuse("Approach the headboard.")
 if state().headboard:return Kit.refuse("The headboard is already open.")
 if not host.quest_state.get("l14_hanging",{}).get("opened",false):return Kit.refuse("Find the passage first.")
 host.quest_state[KEY]={"version":1,"headboard":true,"elapsed":0.0};restore()
 return {"ok":true,"reason":"You push the headboard aside."}
func restore():
 for i in panels.size():panels[i].position.z=(-82 if i==0 else 82)*float(state().elapsed)/2
func _process(delta):
 if host.starting_magic.world_active() and state().headboard and state().elapsed<2:
  var s=state().duplicate(true);s.elapsed=minf(2,s.elapsed+delta);host.quest_state[KEY]=s
 restore();hint.text="E — Push headboard" if reachable() and not state().headboard else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and reachable():
  host.save_feedback(interact().reason);get_viewport().set_input_as_handled()
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
 var shape:=ConcavePolygonShape3D.new();shape.backface_collision=parent.name!="OriginalCrackCeiling2358";shape.set_faces(points)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body)
