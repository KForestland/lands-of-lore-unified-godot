extends Node3D
## G15 Mists3, HINTBOOK5151-5166. Existing I07 evidence identifies source
## prop626, region4900, group40538/local16 Ice_fountain_trigger. The freeze
## receiver and blue tint of that same artwork are modern adapters. No chip
## identity, weapon alternatives, damage, new geometry or collision is inferred.
const KEY:="l16_fountain_freeze"
const RECORD:=626
const REACH:=256.0
var host:Node3D
var source:Dictionary
var frozen_mesh:MeshInstance3D
var original:Transform3D
static func initial()->Dictionary:return {"version":1,"frozen":false}
static func validate(s:Variant,_quests:Dictionary={})->String:
 if not s is Dictionary or s.size()!=2:return "Invalid fountain freeze state."
 var version:Variant=s.get("version")
 if not (version is int or version is float) or version!=1 or not s.get("frozen") is bool:return "Invalid fountain freeze state."
 return ""
static func attach(map:Node3D)->Node:
 var node:Node=load("res://scripts/lol2/l16_fountain_freeze.gd").new()
 node.host=map;node.name="L16FountainFreeze";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for prop:Dictionary in pack.props:
  if int(prop.get("record",-1))==RECORD:source=prop;break
 assert(not source.is_empty() and int(source.region)==4900 and host.prop_placements.has(RECORD),"Source Ice_fountain_trigger626 must be staged")
 var row:Array=host.prop_placements[RECORD]
 var multi:MultiMesh=row[0];original=multi.get_instance_transform(int(row[1]))
 # Fixed-Y billboard scale must respect the hidden source instance as well.
 if multi.mesh is PrimitiveMesh and multi.mesh.material is StandardMaterial3D:
  var mesh:PrimitiveMesh=multi.mesh.duplicate();mesh.material=mesh.material.duplicate();mesh.material.billboard_keep_scale=true;multi.mesh=mesh
 frozen_mesh=MeshInstance3D.new();frozen_mesh.name="FrozenSource626"
 frozen_mesh.position=row[2]
 var quad:=QuadMesh.new()
 quad.size=Vector2(float(source.right)-float(source.left),float(source.top)-float(source.bottom))
 quad.center_offset=Vector3((float(source.left)+float(source.right))/2,(float(source.bottom)+float(source.top))/2,0)
 frozen_mesh.mesh=quad
 var mat:=StandardMaterial3D.new()
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mat.albedo_color=Color(0.55,0.85,1.0)
 mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[source.material]))
 frozen_mesh.material_override=mat;add_child(frozen_mesh)
 # Room visibility controls this parent, freeze state controls its child.
 for nodes:Array in host.cluster_meshes.values():
  var matched:=false
  for node:Node in nodes:
   if node is MultiMeshInstance3D and node.multimesh==multi:matched=true;break
  if matched:nodes.append(self)
 restore()
func aimed()->bool:
 if source.is_empty():return false
 var origin:Vector3=host.camera.global_position
 var point:=Vector3(source.position[0],source.position[1],source.position[2])
 var direction:Vector3=-host.camera.global_basis.z
 var normal:=Vector3(origin.x-point.x,0,origin.z-point.z).normalized()
 var denominator:=direction.dot(normal)
 if absf(denominator)<0.0001:return false
 var distance:float=(point-origin).dot(normal)/denominator
 if distance<=0 or distance>REACH:return false
 var hit:Vector3=origin+direction*distance
 var right:=Vector3(normal.z,0,-normal.x)
 var x:float=(hit-point).dot(right);var y:float=hit.y-point.y
 if x<float(source.left) or x>float(source.right) or y<float(source.bottom) or y>float(source.top):return false
 var query:=PhysicsRayQueryParameters3D.create(origin,hit,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func accepts_player_spell(id:String)->bool:return id=="mists3" and not state().frozen and aimed()
func receive_player_spell(id:String)->bool:
 if not accepts_player_spell(id) or not host.starting_magic.world_active():return false
 host.quest_state[KEY]={"version":1,"frozen":true};restore()
 host.save_feedback("The fountain freezes.");return true
func restore():
 if frozen_mesh==null:return
 var row:Array=host.prop_placements[RECORD]
 var hidden:Transform3D=Transform3D(Basis().scaled(Vector3.ZERO),row[2])
 (row[0] as MultiMesh).set_instance_transform(int(row[1]),hidden if state().frozen else original)
 frozen_mesh.visible=bool(state().frozen)
func _process(_delta:float):restore()
