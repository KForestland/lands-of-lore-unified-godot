extends Node3D
const KEY="l14_spider_passage"
const POINT=Vector3(1351,40,-5396)
const State=preload("res://scripts/lol2/scripted_creature_state.gd")
const RESPAWN_SECONDS=12.0 # Modern book-spawning adapter0286, not a decoded interval.
var host:Node3D
var gate:Node3D
var pack:Dictionary={}
var materials:Dictionary={}
static func initial()->Dictionary:return {"version":1,"breached":false,"kills":0,"counted":false,"timer":0.0}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=5 or s.get("version")!=1 or not s.get("breached") is bool or not s.get("counted") is bool:return "Invalid spider passage."
 if not (s.get("kills") is int or s.get("kills") is float) or s.kills<0 or s.kills!=floor(s.kills) or s.kills>100000:return "Invalid spider defeat count."
 if not (s.get("timer") is int or s.get("timer") is float) or not is_finite(s.timer) or s.timer<0 or s.timer>RESPAWN_SECONDS:return "Invalid spider respawn clock."
 if not s.breached and (s.kills!=0 or s.counted or s.timer!=0):return "Spider encounter before breach."
 if s.breached and not quests.get("l14_hanging",{}).get("opened",false):return "Spider passage lacks open hanging."
 if s.counted and (s.kills<1 or quests.get("act2_creatures_L14_HT",{}).get("actors",{}).get("68",{}).get("health",-1)!=0):return "Spider defeat receipt mismatch."
 if not s.counted and s.timer!=0:return "Respawn clock without corpse."
 return ""
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))==64
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_spider_passage.gd").new();n.host=map;n.name="L14SpiderPassage";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 pack=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file));gate=Node3D.new();gate.name="OriginalCrumblingWall64";add_child(gate)
 var faces:Array=[]
 for f in pack.faces:
  if owns(f):faces.append(f)
 build(gate,faces);restore()
func restore():
 gate.visible=not state().breached;gate.get_node("Collision").collision_layer=0 if state().breached else 1
func _physics_process(delta:float):
 restore()
 if not host.starting_magic.world_active() or host.act2_creatures==null:return
 var s:=state().duplicate(true)
 var distance:float=host.player.position.distance_to(POINT)
 var pop=host.act2_creatures
 if not s.breached:
  if not host.quest_state.get("l14_hanging",{}).get("opened",false) or distance>150:return
  s.breached=true;State.wake(pop.state,"68");pop.sync_quests();host.save_feedback("The wall crumbles. An arachnopod emerges.")
 if pop.state.actors["68"].health<=0:
  if not s.counted:s.counted=true;s.kills+=1;s.timer=0.0
  elif distance<700:
   s.timer=minf(RESPAWN_SECONDS,s.timer+delta)
   if s.timer>=RESPAWN_SECONDS:
    # Gameplay respawn at the original placement after a real combat death.
    var fresh:=State.initial(pop.src)
    pop.state.actors["68"]=fresh.actors["68"];pop.state.live["68"]=fresh.live["68"]
    State.wake(pop.state,"68")
    var p:Array=pop.state.actors["68"].position
    pop.bodies["68"].position=Vector3(p[0],p[1],p[2]);pop.bodies["68"].velocity=Vector3.ZERO
    pop.clocks["68"]=0.0;pop.moving["68"]=false;pop.sync_quests();pop.present()
    s.counted=false;s.timer=0.0
 host.quest_state[KEY]=s;restore()
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
