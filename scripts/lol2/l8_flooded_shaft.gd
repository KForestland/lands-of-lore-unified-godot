extends Node3D
## Owner-approved modern picture/volume from the existing completed flood/shore
## receipts. No new timer, terrain, story event, damage rule or save counter.
const RESTORE_ON:=["load","arrival"]
const REGIONS:=[388,389,391,392,393,394,395,428,429,437,439,440,441,463,466]
const SET:="l8_post_belial_shaft"
var host:Node3D
var mesh:MeshInstance3D
var rows:Array=[]
var shown:=false
static func attach(map:Node3D)->Node:
 var node=load("res://scripts/lol2/l8_flooded_shaft.gd").new();node.host=map;node.name="L8FloodedShaft";map.add_child(node);return node
func flooded()->bool:
 return host.quest_state.get("l9_statue_walk",{}).get("fight_done",false) and host.quest_state.get("l9_escape",{}).get("escaped",false) and host.quest_state.get("l8_shore",{}).get("arrived",false)
func _ready():
 var nav:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/creature_nav/L8_SJ.json"))
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for id:int in REGIONS:
  var raw:Array=nav.regions[id];var polygon:=PackedVector2Array()
  for point:Array in raw[0]:polygon.append(Vector2(point[0],point[1]))
  rows.append({"id":id,"polygon":polygon,"floor":float(raw[1]),"surface":0.0,"bit0":true})
  for corner:int in Geometry2D.triangulate_polygon(polygon):
   var p:=polygon[corner];surface.add_vertex(Vector3(p.x,0.25,p.y))
 mesh=MeshInstance3D.new();mesh.name="PostFloodWater";mesh.mesh=surface.commit()
 var material:=StandardMaterial3D.new();material.albedo_color=Color(0.10,0.29,0.30,0.78);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mesh.material_override=material;add_child(mesh);restore()
func restore():
 if not is_instance_valid(mesh) or not is_instance_valid(host.liquid_drowning):return
 shown=flooded();mesh.visible=shown
 host.liquid_drowning.set_dynamic_regions(SET,rows if shown else [])
func _process(_delta:float):
 if flooded()!=shown:restore()
