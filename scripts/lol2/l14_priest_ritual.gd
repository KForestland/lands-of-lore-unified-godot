extends Node3D
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY="l14_priest_ritual"
const FLOORS={"861":-10,"840":-10,"833":-10,"839":-20,"841":-20,"834":-20,"801":-30,"831":-30,"855":-30,"830":-30,"836":-30,"821":-30,"856":-30,"812":-30,"816":-30,"815":-30,"814":-30,"828":-30,"851":-30,"853":-30,"845":-30,"813":-30}
const LOWER_CEILINGS=[163, 164, 780, 781, 3236, 3237, 3238, 3239, 3240, 3241, 3242, 3243, 3244, 3245, 3246, 3247, 3248, 3253, 3419, 3420, 3421, 3422, 3425, 3427, 3429, 3431]
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
  build(floor_node,faces)
 var ceilings:=Node3D.new();ceilings.name="OriginalLowerRoomCeilings";add_child(ceilings)
 var ceiling_faces:Array=[]
 for f in pack.faces:
  if f.get("kind")=="ceiling" and owns(f):ceiling_faces.append(f)
 build(ceilings,ceiling_faces)
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
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,64);snap.slots=s.slots
 var result:=Kit.offer(snap,recipe(id),item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(id),id)
 if not result.ok:return result
 s.slots=result.snapshot.slots;host.quest_state[KEY]=s;host.carried_collected=result.snapshot.inventory
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
    host.save_feedback(offer(id,host.hand_item if not host.hand_item.is_empty() else INGREDIENTS[id]).reason);get_viewport().set_input_as_handled();return
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
