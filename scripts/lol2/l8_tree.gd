extends Node3D
const Slot=preload("res://scripts/lol2/l8_tree_slot_state.gd")
const KEY="l8_tree"
const FLOORS={"663":[0,210],"664":[10,200],"662":[20,190],"661":[30,180],"670":[40,170],"689":[50,160],"667":[60,150],"669":[70,140],"666":[80,130],"668":[90,120],"665":[100,110]}
const TORCHES={"1338":Vector3(-1121,180,-2146),"1339":Vector3(-997,180,-2187),"1340":Vector3(-883,180,-2268),"1341":Vector3(-824,180,-2436),"1342":Vector3(-864,180,-2595)}
const POINT=Vector3(-1430,250,-2575) # Modern door-face input proxy for original slot66 inside.
const CENTER=Vector3(-938,180,-2326) # Mean of the five torches; modern guidance radius centre (DEVIATIONS 0306).
const NEAR:=420.0
# Owner-reported stuck point 2026-11-03 ("cant raise the platform"); hintbook ch.8 "Tree with Raised Platform".
const JOURNAL_HINTS:=[{"when":"tree_torches_unlit","flag":"l8_tree","hint":"Five torches ring the platform in the great tree. If I light them all with a Spark, something may rise.","enhanced_guard":"same note and near-platform line in both editions"}]
var host:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var floors:Dictionary={}
var flames:Dictionary={}
var gate:Node3D
var hint:Label
class Receiver:
 extends RefCounted
 var owner:Node
 var id:String
 func _init(n:Node,key:String):owner=n;id=key
 func receive_spark_level(level:int)->bool:return owner.spark(id,level)
static func initial()->Dictionary:return {"version":1,"lit":[],"rise":0.0,"lock":Slot.initial()}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=4 or s.get("version")!=1 or not s.get("lit") is Array:return "Invalid tree stairs."
 var seen:Array=[]
 for id in s.lit:
  if not TORCHES.has(id) or id in seen:return "Invalid tree torch receipt."
  seen.append(id)
 if not (s.get("rise") is int or s.get("rise") is float) or not is_finite(s.rise) or s.rise<0 or s.rise>2 or (s.rise>0 and s.lit.size()!=5):return "Invalid tree stair motion."
 var error:=Slot.validate(s.get("lock"),quests)
 if not error.is_empty():return error
 if Slot.unlocked(s.lock) and s.rise<2:return "Tree slot used before stairs rose."
 return ""
static func owns(f:Dictionary)->bool:return (f.get("kind")=="floor" and FLOORS.has(str(int(f.get("region",-1))))) or (f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==50)
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_tree.gd").new();n.host=map;n.name="L8Tree";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in FLOORS:
  var floor_node:=Node3D.new();floor_node.name="OriginalTreeStep"+id;add_child(floor_node);floors[id]=floor_node
  var faces:Array=[]
  for f in pack.faces:
   if f.get("kind")=="floor" and str(int(f.get("region",-1)))==id:faces.append(f)
  build(floor_node,faces)
 gate=Node3D.new();gate.name="OriginalTreeDoor50";add_child(gate)
 var doors:Array=[]
 for f in pack.faces:
  if f.get("placement_kind")=="movable" and int(f.get("source_index",-1))==50:doors.append(f)
 build(gate,doors)
 for id in TORCHES:
  var body:=StaticBody3D.new();body.position=TORCHES[id];body.collision_mask=0;body.set_meta("spark_receiver",Receiver.new(self,id));add_child(body)
  var box:=BoxShape3D.new();box.size=Vector3(28,38,28);var shape:=CollisionShape3D.new();shape.shape=box;body.add_child(shape)
  var flame:=Sprite3D.new();flame.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_torches/flame_0.png"));flame.pixel_size=0.5;flame.position=TORCHES[id];flame.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;flame.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(flame);flames[id]=flame
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
 if host.get("player") is CollisionObject3D: host.player.collision_mask |= 1 << 8
func active()->bool:return host.player_form==0 and not host.flying and host.starting_magic.world_active()
func spark(id:String,level:int)->bool:
 if not active() or not TORCHES.has(id) or level not in [1,3] or id in state().lit:return false
 var s:=state().duplicate(true);s.lit.append(id);host.quest_state[KEY]=s;restore();return true
func reachable()->bool:
 if not active() or state().rise<2:return false
 var d:Vector3=POINT-host.camera.global_position
 return d.length()>0.01 and d.length()<170 and (-host.camera.global_basis.z).dot(d.normalized())>0.85
func interact(action:String,item:String="")->Dictionary:
 if not reachable():return Slot.Kit.refuse("Climb the raised stairs and approach the shard slot.")
 var s:=state().duplicate(true)
 var result:Dictionary=Slot.insert(s.lock,host.carried_collected,item) if action=="insert" else Slot.retrieve(s.lock,host.carried_collected) if action=="retrieve" else Slot.Kit.refuse("Unknown slot action.")
 if not result.ok:return result
 s.lock=result.state;host.quest_state[KEY]=s;host.carried_collected=result.inventory
 if action=="insert" and host.hand_item==item:host.hand_item=""
 Slot.Items.sync(host);restore()
 return {"ok":true,"reason":"The bamboo door opens. Retrieve the shard." if action=="insert" else "You take back the same crystal shard."}
func restore():
 for id in floors:floors[id].position.y=(float(FLOORS[id][1])-float(FLOORS[id][0]))*float(state().rise)/2.0
 for id in flames:flames[id].visible=id in state().lit
 if is_instance_valid(gate):
  var opened:=Slot.unlocked(state().lock);gate.visible=not opened;gate.get_node("Collision").collision_layer=0 if opened else 1
func _physics_process(delta):
 if host.get("starting_magic") != null and host.starting_magic.world_active() and state().lit.size()==5 and state().rise<2:
  var s:=state().duplicate(true);s.rise=minf(2,float(s.rise)+delta);host.quest_state[KEY]=s
 restore()
func near_unraised()->bool:
 if state().lit.size()==5 or not host.starting_magic.world_active():return false
 var d:Vector3=CENTER-host.player.global_position
 return Vector2(d.x,d.z).length()<NEAR
func torch_hint()->String:return "Five torches ring this platform — light each with Spark (Human). Lit %d of 5."%state().lit.size()
func _process(_delta):
 hint.text=""
 if near_unraised():
  preload("res://scripts/lol2/my_journal.gd").discover(host,"tree_torches_unlit")
  hint.text=torch_hint()
 if reachable():hint.text="E — Retrieve crystal shard" if Slot.Kit.slot(state().lock,Slot.TARGET).occupied!="" else "E — Place crystal shard" if not Slot.unlocked(state().lock) else "The tree room is open"
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and reachable():
  var result:Dictionary
  if Slot.Kit.slot(state().lock,Slot.TARGET).occupied!="":result=interact("retrieve")
  else:
   var item:String=host.hand_item
   if item.is_empty():
    for id in host.carried_collected:
     if Slot.Items.definition(id)==105:item=id;break
   result=interact("insert",item)
  host.save_feedback(result.reason);get_viewport().set_input_as_handled()
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
 var body:=AnimatableBody3D.new();body.name="Collision";body.sync_to_physics=false;body.collision_mask=0;body.collision_layer=1<<8
 var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body)
