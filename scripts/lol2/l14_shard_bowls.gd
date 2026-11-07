extends Node3D
const KEY="l14_shard_bowls"
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const SHARDS=["act2:L14_HT:post_shard","act2:L14_HT:item67"]
const BOWLS={"405":Vector3(1176,48,-3307),"406":Vector3(1181,48,-3601)}
var host:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var rear:Node3D
var front:Node3D
var back:Node3D
var crystals:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"slots":{},"opened":0.0}
static func complete(s:Dictionary)->bool:return Kit.slot(s,"405").committed and Kit.slot(s,"406").committed
static func recipe(id:String)->Dictionary:return {"target":id,"accepts":SHARDS,"output":"{item}","retrievable":false,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("slots") is Dictionary:return "Invalid shard bowls."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("opened")) or not is_finite(s.opened) or s.opened<0 or s.opened>2:return "Invalid shard passage motion."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid shard bowl transaction."
 var seen:Array=[]
 for id in s.slots:
  if not BOWLS.has(id):return "Unknown shard bowl."
  var slot:=Kit.slot(s,id)
  if slot.occupied not in SHARDS or slot.occupied in seen or not slot.committed or slot.receipts!=[id] or slot.occupied not in quests.get("act2_items",{}).get("collected",[]):return "Shard bowl receipt mismatch."
  seen.append(slot.occupied)
 if s.opened>0 and not complete(s):return "Passage lacks both shards."
 return ""
static func front_wall(f:Dictionary)->bool:return f.get("kind")=="wall" and int(f.get("region",-1)) in [1013,1014,1015]
static func back_wall(f:Dictionary)->bool:return f.get("kind")=="wall" and f.get("region")==1302 and f.points[0][0]==982 and f.points[2][0]==982
static func owns(f:Dictionary)->bool:return (f.get("kind")=="floor" and int(f.get("region",-1)) in [1019,1020,1021]) or front_wall(f) or back_wall(f)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_shard_bowls.gd").new();n.host=map;n.name="L14ShardBowls";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 rear=Node3D.new();rear.name="OriginalClosedRearRegions1019_1021";add_child(rear)
 front=Node3D.new();front.name="OriginalFrontBarrier1013_1015";add_child(front)
 back=Node3D.new();back.name="OriginalRearBarrier1302";add_child(back)
 var rear_faces:Array=[];var front_faces:Array=[];var back_faces:Array=[]
 for f in pack.faces:
  if owns(f):
   if f.kind=="floor":rear_faces.append(f)
   elif front_wall(f):front_faces.append(f)
   else:back_faces.append(f)
 build(rear,rear_faces);build(front,front_faces);build(back,back_faces)
 for id in BOWLS:
  var crystal:=Sprite3D.new();crystal.texture=ImageTexture.create_from_image(Image.load_from_file(Items.row(SHARDS[0]).icon));crystal.pixel_size=0.5;crystal.position=BOWLS[id]+Vector3.UP*18;crystal.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;crystal.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(crystal);crystals[id]=crystal
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reach(id:String)->bool:
 if not BOWLS.has(id) or host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=BOWLS[id]-host.camera.global_position
 if d.length()<0.01 or d.length()>145 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,BOWLS[id],1,[host.player.get_rid()])
 var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(BOWLS[id])<12
func offer(id:String,item:String,capacity:int=64)->Dictionary:
 if not reach(id):return Kit.refuse("Approach the suspended bowl.")
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,capacity);snap.slots=s.slots
 var result:=Kit.offer(snap,recipe(id),item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(id),id)
 if not result.ok:return result
 s.slots=result.snapshot.slots;host.quest_state[KEY]=s;host.carried_collected=result.snapshot.inventory
 if host.hand_item==item:host.hand_item=""
 Items.sync(host);restore()
 return {"ok":true,"reason":"The passage opens behind the bowls." if complete(s) else "The bowl holds the crystal shard."}
func restore():
 var fraction:float=float(state().opened)/2
 rear.position.y=-170*fraction;front.position.y=-100*fraction;back.position.y=-70*fraction
 for id in crystals:crystals[id].visible=Kit.slot(state(),id).committed
func _physics_process(delta):
 if host.starting_magic.world_active() and complete(state()) and state().opened<2:
  var s=state().duplicate(true);s.opened=minf(2,s.opened+delta);host.quest_state[KEY]=s
 restore()
func _process(_delta):
 hint.text=""
 for id in BOWLS:
  if reach(id) and not Kit.slot(state(),id).committed:hint.text="E — Place green shard in suspended bowl"
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  for id in BOWLS:
   if reach(id) and not Kit.slot(state(),id).committed:
    var item:String=host.hand_item
    if item.is_empty():
     for candidate in SHARDS:
      if candidate in host.carried_collected:item=candidate;break
    host.save_feedback(offer(id,item).reason);get_viewport().set_input_as_handled();return
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
