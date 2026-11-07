extends Node3D
const KEY="l14_library"
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const STAIRS={1567:20,1564:30,1575:40,1570:50,1579:60,1587:70,1591:80,1592:90,2358:10}
const BUTTONS={146:Vector3(2467,35,-5291),147:Vector3(1923,35,-4350),148:Vector3(1672,96,-4912)}
var host:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var floors:Dictionary={}
var crack:Node3D
var door:Node3D
var hint:Label
var exit_parts:Dictionary={}
static func initial()->Dictionary:return {"version":1,"first":false,"second":false,"stairs":0.0,"door":0.0,"exit":false,"exit_time":0.0}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size() not in [5,7] or s.get("version")!=1 or not s.get("first") is bool or not s.get("second") is bool:return "Invalid Temple library."
 for key in ["stairs","door"]:
  if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get(key)) or not is_finite(s[key]) or s[key]<0 or s[key]>2:return "Invalid library motion."
 if (not s.first and s.stairs!=0) or (not s.second and s.door!=0) or (s.second and not s.first):return "Invalid library sequence."
 if s.first and not quests.get("l14_bedroom",{}).get("headboard",false):return "Library lacks bedroom passage."
 if s.has("exit"):
  if not s.exit is bool or not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("exit_time")) or not is_finite(s.exit_time) or s.exit_time<0 or s.exit_time>2:return "Invalid library exit."
  if (s.exit and not s.second) or (not s.exit and s.exit_time!=0):return "Library exit sequence mismatch."
 return ""
static func exit_face(f:Dictionary)->bool:return (f.get("region")==1614 and f.get("kind") in ["floor","ceiling"]) or (f.get("region")==4197 and f.get("kind")=="ceiling")
static func crack_wall(f:Dictionary)->bool:
 return f.get("kind")=="wall" and f.get("region")==2358 and f.points[0][0]==2128 and f.points[2][0]==2128
static func door_face(f:Dictionary)->bool:
 if f.get("kind")=="floor" and f.get("region")==1518:return true
 if f.get("kind")!="wall" or int(f.get("region",-1)) not in [1517,52]:return false
 var x=1989 if f.region==1517 else 2088
 for p in f.points:
  if p[0]!=x or p[1]<0 or p[1]>120 or p[2]< -4406 or p[2]> -4314:return false
 return true
static func owns(f:Dictionary)->bool:
 return (f.get("kind")=="floor" and STAIRS.has(int(f.get("region",-1)))) or crack_wall(f) or door_face(f) or exit_face(f)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_library.gd").new();n.host=map;n.name="L14Library";map.add_child(n);return n
func state()->Dictionary:
 var s=initial();s.merge(host.quest_state.get(KEY,{}),true);return s
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in STAIRS:
  var n:=Node3D.new();n.name="OriginalStair"+str(id);add_child(n);floors[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("kind")=="floor" and f.get("region")==id:faces.append(f)
  build(n,faces)
 crack=Node3D.new();crack.name="OriginalCrackRiser2358";add_child(crack)
 door=Node3D.new();door.name="OriginalLibraryBarrier1518";add_child(door)
 var crack_faces:Array=[];var door_faces:Array=[]
 for f in pack.faces:
  if crack_wall(f):crack_faces.append(f)
  if door_face(f):door_faces.append(f)
 build(crack,crack_faces);build(door,door_faces)
 for key in ["1614:floor","1614:ceiling","4197:ceiling"]:
  var n:=Node3D.new();n.name="OriginalExit"+key.replace(":","_");add_child(n);exit_parts[key]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("region")==int(key.get_slice(":",0)) and f.get("kind")==key.get_slice(":",1):faces.append(f)
  build(n,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,475);canvas.add_child(hint);restore()
func reach(id:int)->bool:
 if not BUTTONS.has(id) or host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=BUTTONS[id]-host.camera.global_position
 return d.length()>0.01 and d.length()<145 and (-host.camera.global_basis.z).dot(d.normalized())>0.9
func interact(id:int)->Dictionary:
 if not reach(id):return Kit.refuse("Approach the hall button.")
 var s=state().duplicate(true)
 if id==146:
  if s.first:return Kit.refuse("The stairs are already lowered.")
  if not host.quest_state.get("l14_bedroom",{}).get("headboard",false):return Kit.refuse("Find the bedroom passage first.")
  s.first=true
 elif id==147:
  if not s.first or s.stairs<2:return Kit.refuse("Press the first hall button first.")
  if s.second:return Kit.refuse("The door is already open.")
  s.second=true
 else:
  if not s.second:return Kit.refuse("Open the library first.")
  if s.exit:return Kit.refuse("The library exit is already open.")
  s.exit=true
 host.quest_state[KEY]=s
 return {"ok":true,"reason":"The stairs descend." if id==146 else "The library door opens." if id==147 else "The library exit opens."}
func restore():
 for id in floors:
  var base=105 if id==1567 else 10 if id==2358 else 100
  floors[id].position.y=(STAIRS[id]-base)*float(state().stairs)/2
 crack.position.y=-80*float(state().stairs)/2
 door.position.y=-120*float(state().door)/2
 for key in exit_parts:exit_parts[key].position.y=({"1614:floor":-40,"1614:ceiling":20,"4197:ceiling":100}[key])*float(state().exit_time)/2
func _physics_process(delta):
 if host.starting_magic.world_active():
  var s=state().duplicate(true)
  if s.first:s.stairs=minf(2,s.stairs+delta)
  if s.second:s.door=minf(2,s.door+delta)
  if s.exit:s.exit_time=minf(2,s.exit_time+delta)
  if s!=state():host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 for id in BUTTONS:
  if reach(id):hint.text="E — Press hall button"
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  for id in BUTTONS:
   if reach(id):host.save_feedback(interact(id).reason);get_viewport().set_input_as_handled();return
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
