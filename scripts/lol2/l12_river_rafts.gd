extends Node3D
## Original raft meshes and opcode18 X/Z words; modern continuous motion and carry.
const KEY="l12_river_rafts"
const IDS=[50,51,55]
const POINTS=[Vector2(1993,-15690),Vector2(3238,-15671),Vector2(4433,-13944),Vector2(2018,-11533),Vector2(1243,-11783),Vector2(252,-13736),Vector2(684,-15112)]
const SPEED=120.0
var host:Node3D
var boats:Array=[]
var origins:Array=[]
var phases:Array=[]
static func length_total()->float:
 var total:=0.0
 for i in POINTS.size():total+=POINTS[i].distance_to(POINTS[(i+1)%POINTS.size()])
 return total
static func initial()->Dictionary:return {"version":1,"distance":0.0}
static func validate(s:Variant)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1:return "Invalid river rafts."
 var d=s.get("distance")
 if not (d is int or d is float) or not is_finite(float(d)) or d<0 or d>=length_total():return "Invalid raft distance."
 return ""
static func sample(distance:float)->Vector2:
 var d:=fposmod(distance,length_total())
 for i in POINTS.size():
  var a:Vector2=POINTS[i];var b:Vector2=POINTS[(i+1)%POINTS.size()];var length:=a.distance_to(b)
  if d<=length:return a.lerp(b,d/length)
  d-=length
 return POINTS[0]
static func nearest_distance(p:Vector2)->float:
 var best:=INF;var result:=0.0;var total:=0.0
 for i in POINTS.size():
  var a:Vector2=POINTS[i];var b:Vector2=POINTS[(i+1)%POINTS.size()];var edge:=b-a
  var t:=clampf((p-a).dot(edge)/edge.length_squared(),0,1);var q:=a+edge*t
  if p.distance_squared_to(q)<best:best=p.distance_squared_to(q);result=total+t*edge.length()
  total+=edge.length()
 return result
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="movable" and int(f.get("source_index",-1)) in IDS
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l12_river_rafts.gd").new();n.host=map;n.name="L12RiverRafts";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in IDS:
  var raw:PackedByteArray=host.progression.native.placements["movable:%d"%id]
  var origin:=Vector2(raw.decode_s16(0),-raw.decode_s16(2));origins.append(origin);phases.append(nearest_distance(origin))
  var boat:=Node3D.new();boat.name="OriginalRaft%d"%id;add_child(boat);boats.append(boat)
  var faces:Array=[]
  for f in pack.faces:
   if owns(f) and int(f.source_index)==id:faces.append(f)
  host.get_node("L12Glacier").build(boat,faces)
  # Manual rider carry is the sole motion owner; no CharacterBody platform velocity.
  var old=boat.get_node("Collision");var body:=StaticBody3D.new();body.name="Collision";body.collision_mask=0
  for child in old.get_children():old.remove_child(child);body.add_child(child)
  boat.remove_child(old);old.queue_free();boat.add_child(body)
 restore()
func centre(index:int)->Vector3:
 var p:=sample(float(state().distance)+phases[index]);return Vector3(p.x,-1181,p.y)
func riding()->int:
 var p:Vector3=host.player.global_position
 if absf(p.y-32+1181)>8:return -1
 var ray:=PhysicsRayQueryParameters3D.create(p,p-Vector3.UP*45,1,[host.player.get_rid()]);var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 if hit.is_empty():return -1
 for i in boats.size():
  if hit.collider==boats[i].get_node("Collision"):return i
 return -1
func restore():
 for i in boats.size():
  var p:=sample(float(state().distance)+phases[i]);boats[i].position=Vector3(p.x-origins[i].x,0,p.y-origins[i].y)
func _physics_process(delta:float):
 if not host.starting_magic.world_active():return
 var rider:=riding();var before:=Vector3.ZERO
 if rider>=0:before=boats[rider].position
 var s:=state().duplicate(true);s.distance=fposmod(float(s.distance)+delta*SPEED,length_total());host.quest_state[KEY]=s;restore()
 if rider>=0:host.player.position+=boats[rider].position-before

func jump_speed(sprint:bool=false)->float:
 # Source bank1000 rises -1190 -> -1090. Existing Human jump peaks only62.5 above raft top.
 if not sprint or host.player_form!=0 or riding()<0:return 200.0
 var p:Vector3=host.player.position
 if Vector2(p.x,p.z).distance_to(Vector2(3144,-12218))>400:return 200.0
 var rise:float=-1090.0-(p.y-32.0)+24.0
 var travel:float=Vector2(p.x,p.z).distance_to(Vector2(3190,-12190))/preload("res://scripts/lol2/walk_feel.gd").RUN_SPEED
 return maxf(sqrt(2.0*320.0*rise),(rise+0.5*320.0*travel*travel)/maxf(travel,0.01))
