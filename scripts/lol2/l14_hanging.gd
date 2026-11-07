extends Node3D
const KEY="l14_hanging"
const POINT=Vector3(2260,45,-3706)
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
var host:Node3D
var gate:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"opened":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("opened") is bool:return "Invalid Temple hanging."
 if s.opened and not quests.get("l14_priest_ritual",{}).get("vanished",false):return "Hanging lacks completed ritual."
 return ""
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))==124
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_hanging.gd").new();n.host=map;n.name="L14Hanging";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 gate=Node3D.new();gate.name="OriginalHanging124";add_child(gate)
 var faces:Array=[]
 for f in pack.faces:
  if owns(f):faces.append(f)
 build(gate,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable()->bool:
 if host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=POINT-host.camera.global_position
 return d.length()>0.01 and d.length()<145 and (-host.camera.global_basis.z).dot(d.normalized())>0.9
func interact()->Dictionary:
 if not reachable():return Kit.refuse("Approach the left wall hanging.")
 if state().opened:return Kit.refuse("The passage is already open.")
 if not host.quest_state.get("l14_priest_ritual",{}).get("vanished",false):return Kit.refuse("Complete the priest's ritual first.")
 host.quest_state[KEY]={"version":1,"opened":true};restore()
 return {"ok":true,"reason":"You draw aside the wall hanging."}
func restore():
 if not is_instance_valid(gate):return
 gate.visible=not state().opened;gate.get_node("Collision").collision_layer=0 if state().opened else 1
func _process(_delta):
 restore();hint.text="E — Draw aside left wall hanging" if reachable() and not state().opened else ""
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
 var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body)
