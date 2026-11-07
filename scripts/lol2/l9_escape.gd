extends Node3D
## Modern physical lift adapter, original table122 and raft82 geometry.
const State=preload("res://scripts/lol2/l9_escape_state.gd")
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
var host:Node3D
var bodies:Dictionary={}
var origins:Dictionary={}
var tunnel_floor:=420.0
var exit_requested:=false
var pool:MeshInstance3D
static func attach(map:Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_escape.gd").new();node.host=map;node.name="L9Escape";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(State.KEY,State.initial())
func enabled()->bool:return host.quest_state.get("l9_statue_walk",{}).get("fight_done",false)
func _ready():
 tunnel_floor=float(host.progression.regions[6304][1])
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L9_DR.json"))
 for id in [122,82]:
  var original=Assemblies.box_body(id,source.boxes[str(id)],Vector3.ZERO)
  var body:=AnimatableBody3D.new();body.sync_to_physics=true
  body.transform=original.transform;body.collision_layer=Assemblies.SCENERY_LAYER;body.collision_mask=0
  for child in original.get_children():original.remove_child(child);body.add_child(child)
  original.free();add_child(body);bodies[id]=body;origins[id]=body.position
  host.preview_assemblies.stateful_meshes[id]=[]
  host.preview_assemblies.set_mode(id,int(source.boxes[str(id)].mode))
 host.player.collision_mask|=Assemblies.SCENERY_LAYER
 pool=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(180,180);pool.mesh=plane
 var water:=StandardMaterial3D.new();water.albedo_color=Color(0.12,0.3,0.35,0.75);water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;water.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 pool.material_override=water;add_child(pool)
 restore(true)
func aboard(id:int)->bool:
 if not host.player.is_on_floor():return false
 for i in host.player.get_slide_collision_count():
  var hit:KinematicCollision3D=host.player.get_slide_collision(i)
  if hit.get_collider()==bodies[id] and hit.get_normal().y>0.7:return true
 return false
func offset()->Vector3:
 var t:float=float(state().lift)
 # Dock beneath the higher tunnel approach ceiling before completing the rise.
 var dock:=Vector3(160,0,-300)*minf(t/8.0,1.0)
 dock.y=lerpf(0,120,t/8.0) if t<8 else lerpf(120,tunnel_floor-59,(t-8)/8.0)
 return dock
func restore(instant:bool=false):
 if instant:exit_requested=false
 var shift:=offset()
 if instant:bodies[122].sync_to_physics=false
 bodies[122].position=origins[122]+shift
 if instant:
  bodies[122].reset_physics_interpolation();bodies[122].sync_to_physics=true
 host.preview_assemblies.set_offset(122,shift)
 var raft_shift:=Vector3(0,float(state().raft)*2,0)
 if instant:bodies[82].sync_to_physics=false
 bodies[82].position=origins[82]+raft_shift
 if instant:bodies[82].reset_physics_interpolation();bodies[82].sync_to_physics=true
 host.preview_assemblies.set_offset(82,raft_shift)
 pool.position=origins[82]+Vector3(0,-5+float(state().raft)*2,0);pool.visible=enabled() and state().raft>0
func _physics_process(delta:float):
 if not enabled() or not host.starting_magic.world_active():return
 var next:=state().duplicate(true)
 if aboard(122):next.boarded=true
 if next.boarded:next.lift=minf(State.DURATION,float(next.lift)+delta)
 if aboard(82) and next.lift==State.DURATION:next.raft=minf(5,float(next.raft)+delta)
 next.escaped=next.raft==5.0
 host.quest_state[State.KEY]=next;restore()
 if next.escaped and not exit_requested:
  exit_requested=true
  # Earned floating completion supplies the original control selector; never preview seed it.
  host.progression.native.set_field("control:82","byte_0x25",2)
  host.progression.use_exit("control:82")
