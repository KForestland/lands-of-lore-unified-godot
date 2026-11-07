extends Node3D
const KEY="l14_niche"
const STATUE="act2:L14_HT:item65"
const SHARD="act2:L14_HT:item67"
const TARGET="temple:niche126"
const POINT=Vector3(2854,25,-3913)
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
var host:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var parts:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"slots":{},"raised":0.0}
static func committed(s:Dictionary)->bool:return Kit.slot(s,TARGET).committed
static func recipe()->Dictionary:return {"target":TARGET,"accepts":[STATUE],"output":"{item}","retrievable":false,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("slots") is Dictionary:return "Invalid statue niche."
 if not preload("res://scripts/lol2/walkthrough_save.gd")._number(s.get("raised")) or not is_finite(s.raised) or s.raised<0 or s.raised>2:return "Invalid niche pedestal motion."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid niche transaction."
 if not s.slots.is_empty():
  var slot:=Kit.slot(s,TARGET)
  if s.slots.size()!=1 or slot.occupied!=STATUE or not slot.committed or slot.receipts!=[TARGET] or STATUE not in quests.get("act2_items",{}).get("collected",[]):return "Niche receipt mismatch."
  if not quests.get("l14_library",{}).get("exit",false):return "Niche lacks library exit."
 if s.raised>0 and not committed(s):return "Pedestal lacks statue."
 if SHARD in quests.get("act2_items",{}).get("collected",[]) and s.raised<2:return "Shard taken before pedestal rises."
 return ""
static func owns(f:Dictionary)->bool:return (f.get("kind")=="floor" and int(f.get("region",-1)) in [381,379,323]) or (f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in [73,74,75])
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_niche.gd").new();n.host=map;n.name="L14Niche";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in [73,74,75,381,379,323]:
  var n:=Node3D.new();n.name="OriginalNichePart"+str(id);add_child(n);parts[id]=n
  var faces:Array=[]
  for f in pack.faces:
   if owns(f) and (f.get("source_index")==id if id<100 else f.get("region")==id):faces.append(f)
  build(n,faces)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable()->bool:
 if host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=POINT-host.camera.global_position
 if d.length()<0.01 or d.length()>145 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,POINT,1,[host.player.get_rid()])
 var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(POINT)<16
func offer(item:String=STATUE,capacity:int=64)->Dictionary:
 if not reachable():return Kit.refuse("Approach the empty statue niche.")
 if not host.quest_state.get("l14_library",{}).get("exit",false):return Kit.refuse("Find the library exit first.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Make room for the pedestal shard.")
 var s:=state().duplicate(true);var snap:=Kit.empty_snapshot(host.carried_collected,capacity);snap.slots=s.slots
 var result:=Kit.offer(snap,recipe(),item,{"form":"human"})
 if not result.ok:return result
 result=Kit.occupy(snap,result.proposal)
 if not result.ok:return result
 result=Kit.commit(result.snapshot,recipe(),TARGET)
 if not result.ok:return result
 s.slots=result.snapshot.slots;host.quest_state[KEY]=s;host.carried_collected=result.snapshot.inventory
 if host.hand_item==item:host.hand_item=""
 Items.sync(host);restore()
 return {"ok":true,"reason":"The statue fits. A crystal rises on the pedestal."}
func restore():
 var fraction:float=float(state().raised)/2
 for id in parts:
  parts[id].position=Vector3(40*fraction,0,0) if id==73 else Vector3(-40*fraction,0,0) if id==74 else Vector3(0,18*fraction,0) if id==75 else Vector3(0,70*fraction,0)
 if host.prop_placements.has(311):
  var row:Array=host.prop_placements[311];row[0].set_instance_transform(row[1],Transform3D(Basis() if committed(state()) else Basis().scaled(Vector3.ZERO),row[2]))
 var items=host.get_node_or_null("Act2WorldItems")
 if items!=null and items.sprites.has(SHARD):items.sprites[SHARD].position.y=-70+70*fraction;items.restore()
func _physics_process(delta):
 if host.starting_magic.world_active() and committed(state()) and state().raised<2:
  var s=state().duplicate(true);s.raised=minf(2,s.raised+delta);host.quest_state[KEY]=s
 restore()
func _process(_delta):hint.text="E — Set machine statue in empty niche" if reachable() and not committed(state()) else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and reachable() and not committed(state()):host.save_feedback(offer(host.hand_item if not host.hand_item.is_empty() else STATUE).reason);get_viewport().set_input_as_handled()
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
