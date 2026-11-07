extends Node3D
const KEY="l14_machines"
const BODY="world:L14_HT:control75"
const TARGET="temple:machine3902"
const STATUE="act2:L14_HT:item65"
const BUTTON=Vector3(2197,-50,-3967)
const BOX=Vector3(2785,-80,-3615)
const INSERT=Vector3(3257,-55,-3615)
const TABLE=Vector3(2150,-45,-3906)
const BELT=Vector3(2403,-75,-3617)
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
var host:Node3D
var box:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
var hint:Label
static func initial()->Dictionary:return {"version":1,"phase":"idle","timer":0.0,"long_first":false,"caught":false,"slots":{}}
static func recipe()->Dictionary:return {"target":TARGET,"accepts":[BODY],"output":"{item}","retrievable":false,"repeatable":false,"forms":["human"]}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=6 or s.get("version")!=1 or s.get("phase") not in ["idle","grinding","ready","carried","pressing","formed","taken"] or not s.get("long_first") is bool or not s.get("caught") is bool or not s.get("slots") is Dictionary:return "Invalid Temple machines."
 if not (s.get("timer") is int or s.get("timer") is float) or not is_finite(s.timer) or s.timer<0 or s.timer>(15.0 if s.phase=="pressing" else 2.0):return "Invalid machine timer."
 var snap:=Kit.empty_snapshot();snap.slots=s.slots
 if not Kit.validate(snap).is_empty():return "Invalid machine transaction."
 if s.phase in ["pressing","formed","taken"]:
  var slot:=Kit.slot(s,TARGET)
  if s.slots.size()!=1 or slot.occupied!=BODY or not slot.committed or slot.receipts!=[TARGET] or not s.long_first:return "Machine lacks aligned box receipt."
 elif not s.slots.is_empty():return "Machine receipt before insertion."
 if s.phase!="idle" and not quests.get("l14_priest_ritual",{}).get("vanished",false):return "Machine lacks completed ritual."
 if (s.phase=="taken")!=(STATUE in quests.get("act2_items",{}).get("collected",[])):return "Machine statue receipt mismatch."
 if s.caught and s.phase!="taken":return "Catch before statue pickup."
 return ""
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))==75
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_machines.gd").new();n.host=map;n.name="L14Machines";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file));box=Node3D.new();box.name="OriginalBloodTrough75";add_child(box)
 var faces:Array=[]
 for f in pack.faces:
  if owns(f):
   var local:Dictionary=f.duplicate(true)
   for p in local.points:p[0]-=BOX.x;p[1]-=BOX.y;p[2]-=BOX.z
   faces.append(local)
 build(box,faces);box.get_node("Collision").collision_layer=0
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func active()->bool:return host.player_form==0 and not host.flying and host.starting_magic.world_active()
func reach(point:Vector3)->bool:
 if not active():return false
 var d:Vector3=point-host.camera.global_position
 return d.length()>0.01 and d.length()<145 and (-host.camera.global_basis.z).dot(d.normalized())>0.85
func interact(action:String,item:String=BODY,capacity:int=64)->Dictionary:
 var s:=state().duplicate(true)
 if action=="start":
  if s.phase!="idle" or not reach(BUTTON) or not host.quest_state.get("l14_priest_ritual",{}).get("vanished",false):return Kit.refuse("Approach the pedestal beside the table.")
  s.phase="grinding";s.timer=0.0
 elif action=="carry":
  if s.phase!="ready" or not reach(BOX+Vector3.UP*12):return Kit.refuse("Approach the filled trough behind the grinder.")
  s.phase="carried"
 elif action=="rotate":
  if s.phase!="carried" or not active():return Kit.refuse("Carry the trough first.")
  s.long_first=not s.long_first
 elif action=="insert":
  if s.phase!="carried" or not reach(INSERT):return Kit.refuse("Carry the trough to the second machine.")
  if not s.long_first:return Kit.refuse("Turn the trough so its long edge enters first.")
  if host.carried_collected.size()>=capacity:return Kit.refuse("Make room to catch the statue.")
  var snap:=Kit.empty_snapshot([BODY],1);snap.slots=s.slots
  var result:=Kit.offer(snap,recipe(),item,{"form":"human"})
  if not result.ok:return result
  result=Kit.occupy(snap,result.proposal)
  if not result.ok:return result
  result=Kit.commit(result.snapshot,recipe(),TARGET)
  if not result.ok:return result
  s.slots=result.snapshot.slots;s.phase="pressing";s.timer=0.0
 else:return Kit.refuse("Unknown machine action.")
 host.quest_state[KEY]=s;restore()
 return {"ok":true,"reason":{"grinding":"The body moves onto the grinder's belt.","carried":"You carry the trough, long edge first." if s.long_first else "You carry the trough, short edge first.","pressing":"The trough slides in. Move to the back of the machine!"}.get(s.phase,"The machine moves.")}
func note_pickup():
 var s:=state().duplicate(true)
 if s.phase!="formed":return
 s.caught=s.timer<2.0;s.phase="taken";host.quest_state[KEY]=s
func restore():
 var s:=state()
 box.visible=s.phase in ["ready","carried"]
 box.position=BOX;box.rotation.y=PI/2 if s.long_first else 0.0
 if s.phase=="carried":
  var forward:Vector3=-host.camera.global_basis.z;forward.y=0
  box.position=host.player.position+forward.normalized()*38-Vector3.UP*20
 if host.prop_placements.has(187):
  var row:Array=host.prop_placements[187]
  var at:Vector3=TABLE.lerp(BELT,s.timer/2.0) if s.phase=="grinding" else TABLE
  row[0].set_instance_transform(row[1],Transform3D(Basis() if s.phase in ["idle","grinding"] else Basis().scaled(Vector3.ZERO),at))
 var items=host.get_node_or_null("Act2WorldItems")
 if items!=null and items.sprites.has(STATUE):
  items.sprites[STATUE].position=Vector3(3325,-54-s.timer/2.0 if s.phase=="formed" else -54,-3617)
  items.sprites[STATUE].visible=s.phase=="formed"
func _physics_process(delta:float):
 var s:=state().duplicate(true)
 if host.starting_magic.world_active() and s.phase in ["grinding","pressing","formed"]:
  s.timer=minf(15.0 if s.phase=="pressing" else 2.0,s.timer+delta)
  if s.phase=="grinding" and s.timer>=2:s.phase="ready"
  elif s.phase=="pressing" and s.timer>=15:s.phase="formed";s.timer=0.0
  host.quest_state[KEY]=s
 restore()
func _process(_delta):
 var s:=state();hint.text=""
 if s.phase=="idle" and reach(BUTTON):hint.text="E — Press the pedestal button"
 elif s.phase=="ready" and reach(BOX+Vector3.UP*12):hint.text="E — Carry filled trough"
 elif s.phase=="carried":hint.text="E — Insert trough; G — Turn long edge first" if reach(INSERT) else "Carrying trough; G — Turn trough"
func _unhandled_key_input(event:InputEvent):
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode==KEY_G and state().phase=="carried":host.save_feedback(interact("rotate").reason);get_viewport().set_input_as_handled();return
 if event.keycode!=KEY_E:return
 var action:="start" if state().phase=="idle" and reach(BUTTON) else "carry" if state().phase=="ready" and reach(BOX+Vector3.UP*12) else "insert" if state().phase=="carried" and reach(INSERT) else ""
 if not action.is_empty():host.save_feedback(interact(action).reason);get_viewport().set_input_as_handled()
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
