extends Node3D
const Grants=preload("res://scripts/lol2/item_grants.gd")
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY="l14_priest_ritual"
const FLOORS={"861":-10,"840":-10,"833":-10,"839":-20,"841":-20,"834":-20,"801":-30,"831":-30,"855":-30,"830":-30,"836":-30,"821":-30,"856":-30,"812":-30,"816":-30,"815":-30,"814":-30,"828":-30,"851":-30,"853":-30,"845":-30,"813":-30}
const LOWER_CEILINGS=[163, 164, 780, 781, 3236, 3237, 3238, 3239, 3240, 3241, 3242, 3243, 3244, 3245, 3246, 3247, 3248, 3253, 3419, 3420, 3421, 3422, 3425, 3427, 3429, 3431,
	# the upper way's lower ceilings (tools/build_l14_ritual_ceiling_collision.py UPPER_CEILINGS; slab-to-pew 2026-11-13)
	3254, 3255, 3256, 3257, 3258, 3259, 3260, 3261, 3262, 3263, 3264, 3267, 3270, 3274, 3278, 3282, 3283, 3287, 3345, 3346, 3347, 3348, 3349, 3350, 3351, 3352, 3353, 3354, 3355, 3356, 3358, 3359, 3360, 3361, 3362, 3363, 3364, 3365, 3366, 3368, 3872, 3876, 3877, 3885, 3886, 3887, 3888, 3891, 3895, 3899, 3903]
const BOWLS={"369":Vector3(2441,30,-3691),"370":Vector3(2375,30,-3691)}
const INGREDIENTS={"369":"act2:L14_HT:item72","370":"act2:L14_HT:item68"}
const SPARK=Vector3(2413,9,-3328)
var host:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var floors:Dictionary={}
var hint:Label
class Receiver:
 extends RefCounted
 var owner:Node
 func _init(n:Node):owner=n
 func receive_spark_level(level:int)->bool:return owner.spark(level)
static func initial()->Dictionary:return {"version":1,"slots":{},"lowered":0.0,"vanished":false}
static func complete(s:Dictionary)->bool:return Kit.slot(s,"369").committed and Kit.slot(s,"370").committed
static func recipe(id:String)->Dictionary:return {"target":id,"accepts":[INGREDIENTS[id]],"output":"{item}","retrievable":false,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("slots") is Dictionary or not s.get("vanished") is bool:return "Invalid Temple ritual."
 if not (s.get("lowered") is float or s.get("lowered") is int) or not is_finite(s.lowered) or s.lowered<0 or s.lowered>2:return "Invalid ritual floor motion."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid bowl transaction."
 for id in s.slots:
  if not INGREDIENTS.has(id):return "Unknown ritual bowl."
  var slot:=Kit.slot(s,id)
  if slot.occupied!=INGREDIENTS[id] or not slot.committed or slot.receipts!=[id] or INGREDIENTS[id] not in quests.get("act2_items",{}).get("collected",[]):return "Bowl receipt mismatch."
 if not s.slots.is_empty() and quests.get("l14_priest_body",{}).get("phase")!="placed":return "Ritual lacks placed body."
 if s.lowered>0 and not complete(s):return "Floor lacks both ingredients."
 if s.vanished and (not complete(s) or s.lowered<2):return "Body vanished before ritual."
 return ""
static func owns(f:Dictionary)->bool:return (f.get("kind")=="floor" and FLOORS.has(str(int(f.get("region",-1))))) or (f.get("kind")=="ceiling" and int(f.get("region",-1)) in LOWER_CEILINGS)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_priest_ritual.gd").new();n.host=map;n.name="L14PriestRitual";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in FLOORS:
  var floor_node:=Node3D.new();floor_node.name="RitualFloor"+id;add_child(floor_node);floors[id]=floor_node
  var faces:Array=[]
  for f in pack.faces:
   if f.get("kind")=="floor" and owns(f) and str(int(f.region))==id:faces.append(f)
  build(floor_node,faces,Vector3.UP)
 var ceilings:=Node3D.new();ceilings.name="OriginalLowerRoomCeilings";add_child(ceilings)
 var ceiling_faces:Array=[]
 for f in pack.faces:
  if f.get("kind")=="ceiling" and owns(f):ceiling_faces.append(f)
 build(ceilings,ceiling_faces,Vector3.DOWN)
 var clipped:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l14_ritual_ceiling_collision.json"))
 var collision_points:=PackedVector3Array()
 for p in clipped.points:collision_points.append(Vector3(p[0],p[1],p[2]))
 ceilings.get_node("Collision").get_child(0).shape.set_faces(collision_points)
 var receiver:=StaticBody3D.new();receiver.position=SPARK;receiver.collision_mask=0;receiver.set_meta("spark_receiver",Receiver.new(self));add_child(receiver)
 var box:=BoxShape3D.new();box.size=Vector3(58,14,26);var shape:=CollisionShape3D.new();shape.shape=box;receiver.add_child(shape)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,480);canvas.add_child(hint);restore()
func active()->bool:return host.player_form==0 and not host.flying and host.starting_magic.world_active()
func reach(point:Vector3)->bool:
 if not active():return false
 var d:Vector3=point-host.camera.global_position
 return d.length()>0.01 and d.length()<160 and (-host.camera.global_basis.z).dot(d.normalized())>0.9
func offer(id:String,item:String)->Dictionary:
 if not BOWLS.has(id) or not reach(BOWLS[id]):return Kit.refuse("Approach the ritual bowl.")
 if host.quest_state.get("l14_priest_body",{}).get("phase")!="placed":return Kit.refuse("Place the priest on the stone rectangle first.")
 if item not in host.carried_collected:return Kit.refuse("The bowl needs Poison Paint." if id=="369" else "The bowl needs aloe.")
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,64);snap.slots=s.slots
 var result:=Kit.offer(snap,recipe(id),item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(id),id)
 if not result.ok:return result
 s.slots=result.snapshot.slots;var admission:=Grants.transition(host,result.snapshot.inventory,{KEY:s})
 if not admission.ok:return admission
 if host.hand_item==item:host.hand_item=""
 Items.sync(host)
 return {"ok":true,"reason":"The floor begins to descend." if complete(s) else "The bowl holds the offering."}
func spark(level:int)->bool:
 if not active() or level not in [1,3] or state().lowered<2 or state().vanished:return false
 var s:=state().duplicate(true);s.vanished=true;host.quest_state[KEY]=s;host.get_node("L14PriestBody").restore();host.save_feedback("The priest's body disappears.");return true
func restore():
 for id in floors:floors[id].position.y=float(FLOORS[id])*float(state().lowered)/2.0
func _physics_process(delta):
 if host.starting_magic.world_active() and complete(state()) and state().lowered<2:
  var s:=state().duplicate(true);s.lowered=minf(2.0,float(s.lowered)+delta);host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 for id in BOWLS:
  if reach(BOWLS[id]) and not Kit.slot(state(),id).committed:hint.text="E — Offer poison" if id=="369" else "E — Offer aloe"
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  for id in BOWLS:
   if reach(BOWLS[id]) and not Kit.slot(state(),id).committed:
    host.save_feedback(offer(id,host.hand_item if host.hand_item==INGREDIENTS[id] and host.hand_item in host.carried_collected else INGREDIENTS[id]).reason);get_viewport().set_input_as_handled();return
## G-14 (owner report 2026-11-12 06-29-47): the descended ritual floors were drawn double-sided and outside portal drawing,
## so from the lower room they showed their undersides as planes in the air. Each mesh now faces `toward` only (floors
## seen from above, ceilings from below, like the 2.5D original) and joins its room's portal batch (host.cluster_meshes)
## so it hides with that room. Collision keeps the source order.
func build(parent:Node3D,faces:Array,toward:=Vector3.ZERO)->void:
 var groups:Dictionary={};var points:=PackedVector3Array();var group_room:Dictionary={}
 for face in faces:
  var room:int=int(host.region_cluster.get(int(face.get("region",-1)),-1)) if host.get("region_cluster") is Dictionary else -1
  var key:=str(face.material)+"@"+str(room)
  if not groups.has(key):
   var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]=tool;group_room[key]=room
  var order:=[0,1,2,0,2,3]
  if toward!=Vector3.ZERO:
   var a:=Vector3(face.points[0][0],face.points[0][1],face.points[0][2]);var b:=Vector3(face.points[1][0],face.points[1][1],face.points[1][2]);var c:=Vector3(face.points[2][0],face.points[2][1],face.points[2][2])
   order=[0,2,1,0,3,2] if (b-a).cross(c-a).dot(toward)>0 else [0,1,2,0,2,3]
  for i in order:
   var p:=Vector3(face.points[i][0],face.points[i][1],face.points[i][2]);groups[key].set_uv(Vector2(face.uv[i][0],face.uv[i][1]));groups[key].add_vertex(p)
  for i in [0,1,2,0,2,3]:points.append(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
 for key in groups:
  groups[key].generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=groups[key].commit()
  var mat_key:=str(key).get_slice("@",0)+("|one" if toward!=Vector3.ZERO else "")
  if not materials.has(mat_key):
   var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[str(key).get_slice("@",0)]));mat.cull_mode=BaseMaterial3D.CULL_BACK if toward!=Vector3.ZERO else BaseMaterial3D.CULL_DISABLED;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;materials[mat_key]=mat
  mesh.material_override=materials[mat_key];parent.add_child(mesh)
  var listed:Variant=host.get("cluster_meshes")
  if listed is Dictionary and int(group_room[key])>=0:
   if not listed.has(int(group_room[key])):listed[int(group_room[key])]=[]
   listed[int(group_room[key])].append(mesh)
 var body:=AnimatableBody3D.new();body.name="Collision";body.sync_to_physics=false;body.collision_mask=0
 var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body)
