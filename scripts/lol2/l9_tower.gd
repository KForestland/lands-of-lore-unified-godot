extends Node3D
## Book-led tower alcoves and stair fields, bound only to the source records in SOURCE.
const SOURCE="res://scripts/lol2/l9_tower_source.json"
const Blockers=preload("res://scripts/lol2/region_blockers.gd")
var host: Node3D
var source: Dictionary
var blocker: Node
var visual_blocker: Node
var field_mesh: MeshInstance3D
var aims: Dictionary={}
var transports: Array=[]
var transport_wait:=0.0
var presentation: Array=[]
class Receiver:
 extends RefCounted
 var owner_node: Node
 var id: String
 func _init(node: Node,key: String):owner_node=node;id=key
 func receive_spark()->bool:return owner_node.light(id)
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_tower.gd").new()
 node.host=map;node.name="L9Tower";map.add_child(node);return node
static func initial()->Dictionary:return {"version":1,"orbs":[]}
static func validate(value: Variant)->String:
 if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("orbs") is Array:return "Invalid tower state."
 var seen: Array=[]
 for id in value.orbs:
  if id not in ["1090","1088","1087","1089"] or id in seen:return "Invalid tower orb."
  seen.append(id)
 return ""
func state()->Dictionary:return host.quest_state.get("l9_tower",initial())
func _ready():
 source=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Blockers.path_for("L9_DR")))
 var owned: Array=[]
 for id in source.orbs:
  for region in source.orbs[id].regions:owned.append(int(region))
  var p: Array=source.orbs[id].position;aims[id]=Vector3(p[0],p[1],p[2])
  var receiver:=StaticBody3D.new();receiver.position=aims[id]
  receiver.collision_layer=1;receiver.collision_mask=0;receiver.set_meta("spark_receiver",Receiver.new(self,id))
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(26,57,12);shape.shape=box
  receiver.add_child(shape);add_child(receiver)
 blocker=Blockers.new();blocker.name="TowerFields";blocker.player=host.player
 blocker.collision_layer=Blockers.LAYER;blocker.collision_mask=0
 for n in owned:
  var key:=str(int(n))
  blocker.dynamic_state[int(n)]=pack.dynamic_initial[key]
  blocker._dynamic_outlines[key]=pack.dynamic_outlines[key]
  blocker._dynamic_heights[key]=pack.dynamic_heights[key]
 for edge in pack.dynamic_edges:
  if int(edge.to_dynamic) not in owned:continue
  var copy: Dictionary=edge.duplicate(true);copy.footroom=0.0;copy.headroom=0.0
  blocker.dynamic_edges.append(copy)
 blocker.static_shape=CollisionShape3D.new();blocker.add_child(blocker.static_shape)
 blocker.rebuild_static(blocker.player_radius()+Blockers.CLEARANCE_MARGIN)
 add_child(blocker);blocker.enable_dynamic();host.player.collision_mask|=Blockers.LAYER
 visual_blocker=blocker
 var global_blocker=host.get_node_or_null("RegionBlockers")
 if global_blocker!=null:
  # One physics/mask owner for the map; this local shape only builds the Tower field artwork.
  visual_blocker.collision_layer=0;visual_blocker.set_physics_process(false)
  blocker=global_blocker
  for edge in blocker.dynamic_edges:
   if int(edge.to_dynamic) in owned:edge.footroom=0.0;edge.headroom=0.0
  blocker._rebuild_dynamic()
 field_mesh=MeshInstance3D.new();add_child(field_mesh)
 var material:=StandardMaterial3D.new();material.albedo_color=Color(0.1,0.8,0.25,0.22)
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;field_mesh.material_override=material
 restore(true)
func light(id: String)->bool:
 if not source.orbs.has(id) or id in state().orbs:return false
 var next:=state().duplicate(true);next.orbs.append(id);host.quest_state.l9_tower=next
 restore();host.save_feedback("The stairway field fades.");return true
func restore(force: bool=false):
 var lit: Array=state().orbs
 if not force and presentation==lit:return
 presentation=lit.duplicate()
 for id in source.orbs:
  for n in source.orbs[id].regions:
   blocker.dynamic_state[int(n)]=id not in lit
   visual_blocker.dynamic_state[int(n)]=id not in lit
 blocker._rebuild_dynamic()
 if visual_blocker!=blocker:visual_blocker._rebuild_dynamic()
 var vertices: PackedVector3Array=visual_blocker.dynamic_shape.shape.get_faces()
 field_mesh.visible=not vertices.is_empty()
 if not vertices.is_empty():
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for vertex in vertices:surface.add_vertex(vertex)
  surface.generate_normals();field_mesh.mesh=surface.commit()
func _process(_delta):restore()
func _physics_process(delta: float):
 transport_wait=maxf(0.0,transport_wait-delta)
 if transport_wait>0 or get_tree().paused or host.flying or not host.starting_magic.world_active():return
 var feet: float=host.player.position.y-32
 for entry in source.transports:
  for region in entry.regions:
   var row: Array=host.progression.regions[int(region)]
   if absf(feet-float(row[1]))>40 or not host.progression._inside(int(region),host.player.position):continue
   var p: Array=entry.position;var landing:=Vector3(p[0],p[1],p[2])
   # This is an earned production alcove transport, never a test-position setup.
   host.player.position=landing;host.player.velocity=Vector3.ZERO
   host.player.rotation.y=-TAU*float(entry.heading)/65536.0;host.camera.rotation.x=0
   host.progression.enter_region(host.progression.region_at(landing))
   transports.append({"region":int(region),"position":p.duplicate(),"raw_hex":entry.raw_hex})
   transport_wait=0.5;return
