extends Node3D
const KEY="l14_tilt"
const LOWER_CEILINGS=[738, 739, 740, 741, 742, 743, 744, 745, 746, 747, 748, 749, 750, 751, 752, 753, 754, 755, 756, 757, 758, 759, 760, 761, 762, 763, 764, 765, 766, 767, 768, 769, 770, 771, 772, 773, 774, 775, 776, 777, 1305, 1308, 1309, 1310, 1311, 2283, 2284, 2285, 2286, 2287, 2288, 2289, 4025, 4026, 4027, 4028, 4029, 4030, 4031, 4032, 4033, 4034, 4035]
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const BUTTONS={"142":Vector3(-399,385,-973),"143":Vector3(-399,385,327),"144":Vector3(428,385,356),"145":Vector3(428,385,-944)}
var host:Node3D
var halves:Dictionary={}
var polygons:Dictionary={}
var barrier:Node3D
var hint:Label
var shown:=INF
static func initial()->Dictionary:return {"version":1,"started":false,"side":1,"elapsed":0.0,"buttons":[],"settled":0.0,"finish_left":0.0}
static func solved(s:Dictionary)->bool:return s.buttons.size()==4
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=7 or s.get("version")!=1 or not s.get("started") is bool or (s.get("side")!=-1 and s.get("side")!=1) or not s.get("buttons") is Array:return "Invalid tilting-floor state."
 for key in ["elapsed","settled","finish_left"]:
  if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get(key)) or not is_finite(s[key]):return "Invalid floor timing."
 if s.elapsed<0 or s.elapsed>60 or s.settled<0 or s.settled>2 or absf(s.finish_left)>150:return "Invalid floor range."
 var seen:Array=[]
 for id in s.buttons:
  if not id is String or not BUTTONS.has(id) or id in seen:return "Invalid high-button receipt."
  seen.append(id)
 if not s.started:return "" if s==initial() else "Unstarted floor changed."
 if "89" not in quests.get("l14_trials",{}).get("doors",[]):return "Tilt room lacks middle door."
 if not solved(s) and (s.settled!=0 or s.finish_left!=0):return "Unsolved floor settled."
 return ""
static func barrier_face(f:Dictionary)->bool:
 if f.get("kind")=="floor":return int(f.get("region",-1))==2291
 if f.get("kind")!="wall" or int(f.get("region",-1)) not in [2684,2290]:return false
 var lo:=INF;var hi:=-INF
 for p in f.points:lo=minf(lo,p[1]);hi=maxf(hi,p[1])
 if lo!=190 or hi!=340:return false
 if int(f.region)==2684:return true
 for p in f.points:
  if p[2]!=1180:return false
 return true
static func side_wall(f:Dictionary)->bool:
 if f.get("kind")!="wall" or int(f.get("region",-1)) not in [2132,2133]:return false
 var low:=INF;var high:=-INF
 for p in f.points:low=minf(low,p[1]);high=maxf(high,p[1])
 return low==190 and high==400
static func owns(f:Dictionary)->bool:return (f.get("kind")=="floor" and int(f.get("region",-1)) in [2132,2133]) or (f.get("kind")=="ceiling" and int(f.get("region",-1)) in LOWER_CEILINGS) or side_wall(f) or barrier_face(f)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_tilt.gd").new();n.host=map;n.name="L14Tilt";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in [2132,2133]:
  var n:=Node3D.new();n.name="OriginalTiltHalf"+str(id);add_child(n);halves[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if f.get("kind")=="floor" and int(f.get("region",-1))==id:faces.append(f);polygons[id]=f.points
  assert(faces.size()==1,"Missing original tilt half")
  host.get_node("L14Niche").build(n,faces)
  var shape:=ConvexPolygonShape3D.new();var initial_points:=PackedVector3Array()
  for p in polygons[id]:initial_points.append(Vector3(p[0],190,p[2]));initial_points.append(Vector3(p[0],40,p[2]))
  shape.points=initial_points;n.get_node("Collision").get_child(0).shape=shape
  var sides:=MeshInstance3D.new();sides.name="MovingFloorSides";sides.material_override=n.get_child(0).material_override;n.add_child(sides)
 barrier=Node3D.new();barrier.name="OriginalFarBarrier2291";add_child(barrier)
 var faces:Array=[]
 for f in pack.faces:
  if barrier_face(f):faces.append(f)
 assert(faces.size()==3,"Expected original barrier floor andtwo boundary walls")
 host.get_node("L14Niche").build(barrier,faces.filter(func(f):return f.kind=="floor"))
 var barrier_sides:=Node3D.new();barrier_sides.name="RetractingSides";barrier.add_child(barrier_sides)
 host.get_node("L14Niche").build(barrier_sides,faces.filter(func(f):return f.kind=="wall"))
 var sides:=Node3D.new();sides.name="OriginalOuterWallsExtendedToLowFloor";add_child(sides)
 var walls:Array=[]
 for f in pack.faces:
  if side_wall(f):
   var face:Dictionary=f.duplicate(true)
   for p in face.points:
    if p[1]==190:p[1]=40
   walls.append(face)
 assert(walls.size()==2,"Original outer wall ownership")
 host.get_node("L14Niche").build(sides,walls)
 build_clipped_ceilings(pack)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func left_offset()->float:
 var s:=state()
 if not s.started:return 0
 if solved(s):return float(s.finish_left)*(1-float(s.settled)/2)
 var value:float
 if s.elapsed<4:value=150*float(s.elapsed)/4
 else:
  var t:=fmod(float(s.elapsed)-4,56)
  value=150 if t<20 else 150-300*(t-20)/8 if t<28 else -150 if t<48 else -150+300*(t-48)/8
 return value*float(s.side)
var shown_settled:bool=false
func restore():
 if not is_instance_valid(barrier):return
 var offset:=left_offset()
 var settled:bool=state().settled==2
 if offset!=shown or settled!=shown_settled:
  shown=offset;shown_settled=settled
  for id in halves:
   var n:Node3D=halves[id];var lift:float=offset if id==2132 else -offset;n.position.y=lift
   var points:=PackedVector3Array();var top:Array=[];var bottom:Array=[]
   for p in polygons[id]:
    var a:=Vector3(p[0],190,p[2]);var b:=Vector3(p[0],189 if settled else minf(40-lift,189),p[2]);top.append(a);bottom.append(b);points.append(a);points.append(b)
   n.get_node("Collision").get_child(0).shape.points=points
   var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   for i in 4:
    var j:=(i+1)%4
    var quad:Array=[bottom[i],bottom[j],top[j],top[i]]
    for index in [0,1,2,0,2,3]:tool.set_uv(Vector2(1 if index in [1,2] else 0,1 if index>1 else 0));tool.add_vertex(quad[index])
   tool.generate_normals();n.get_node("MovingFloorSides").mesh=tool.commit()
 barrier.position.y=-150*float(state().settled)/2
 var barrier_sides:Node3D=barrier.get_node("RetractingSides")
 barrier_sides.visible=not settled
 barrier_sides.get_node("Collision").collision_layer=0 if settled else 1
func reachable(id:String)->bool:
 if not BUTTONS.has(id) or host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var point:Vector3=BUTTONS[id];var d:Vector3=point-host.camera.global_position
 if d.length()<0.01 or d.length()>125 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()]);var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(point)<18
func press(id:String)->Dictionary:
 if not reachable(id) or not state().started:return Kit.refuse("Ride the floor up to the high button.")
 var s:=state().duplicate(true)
 if id in s.buttons:return Kit.refuse("That button is already pressed.")
 if s.buttons.size()==3:s.finish_left=left_offset()
 s.buttons.append(id);host.quest_state[KEY]=s;restore()
 return {"ok":true,"reason":"The floor levels and the far passage opens." if solved(s) else "A high button clicks into place."}
func _physics_process(delta):
 if host.starting_magic.world_active():
  var s:=state().duplicate(true);var p:Vector3=host.player.position
  if not s.started and "89" in host.quest_state.get("l14_trials",{}).get("doors",[]) and p.x>-400 and p.x<430 and p.z>-1197 and p.z<612 and p.y>200:
   s.started=true;s.side=1 if p.x<2 else -1
  if s.started:
   if solved(s):s.settled=minf(2,s.settled+delta)
   else:
    s.elapsed+=delta
    if s.elapsed>60:s.elapsed-=56
   host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 for id in BUTTONS:
  if reachable(id) and id not in state().buttons:hint.text="E — Press high button";return
func _unhandled_key_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 for id in BUTTONS:
  if reachable(id) and id not in state().buttons:host.save_feedback(press(id).reason);get_viewport().set_input_as_handled();return

func build_clipped_ceilings(pack:Dictionary):
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l14_tilt_ceiling_clip.json"))
 var groups:Dictionary={};var points:=PackedVector3Array()
 for face in data.faces:
  if not groups.has(face.material):
   var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);groups[face.material]=tool
  for i in 3:
   var p:=Vector3(face.points[i][0],face.points[i][1],face.points[i][2]);groups[face.material].set_uv(Vector2(face.uv[i][0],face.uv[i][1]));groups[face.material].add_vertex(p);points.append(p)
 var node:=Node3D.new();node.name="LowerCeilingsOutsideUpperRoute";add_child(node)
 for key in groups:
  groups[key].generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=groups[key].commit()
  var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[key]));mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mesh.material_override=mat;node.add_child(mesh)
 var body:=StaticBody3D.new();body.collision_mask=0;node.add_child(body)
 var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
