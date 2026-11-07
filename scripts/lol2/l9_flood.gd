extends Node3D
## One owner of the post-fight rising water and its saved drowning clock.
const State=preload("res://scripts/lol2/l9_flood_state.gd")
const Form=preload("res://scripts/lol2/player_form_body.gd")
var host: Node3D
var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l9_flood_source.json"))
var rows: Array=[]
var surfaces: Array=[]
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_flood.gd").new();node.host=map;node.name="L9Flood";map.add_child(node);return node
func enabled()->bool:return host.quest_state.get("l9_statue_walk",{}).get("fight_done",false)
func state()->Dictionary:return host.quest_state.get("l9_flood",State.initial())
func _ready():
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 # Source preset59 Shallow North has resource511; preserve the original first water frame.
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/dragon_level/area.json"))
 material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/dragon_level/"+str(data.materials["511"])))
 var commands:Array=source.floor_commands.duplicate(true)
 var later:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/l9_flood_sectors.json"))
 for span in later.spans:
  for row in span.regions:
   var copy:Dictionary=row.duplicate(true);copy.later=true;commands.append(copy)
 for row in commands:
  var polygon:=PackedVector2Array()
  for point in row.polygon:polygon.append(Vector2(point[0],point[1]))
  rows.append({"source":row,"polygon":polygon})
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material)
  for i in Geometry2D.triangulate_polygon(polygon):
   var p: Vector2=polygon[i];tool.set_uv(p/128.0);tool.add_vertex(Vector3(p.x,0,p.y))
  var surface:=MeshInstance3D.new();surface.mesh=tool.commit();add_child(surface);surfaces.append(surface)
 visible=false
func submerged()->bool:
 var p: Vector3=host.player.position
 var feet: float=p.y-Form.FOOT_OFFSET
 var top: float=feet+(0 if host.player_form==2 else Form.HEIGHTS[host.player_form])
 for row in rows:
  if feet<float(row.source.floor[0])-64:continue
  if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),row.polygon) and top<State.height(row.source,float(state().elapsed)):return true
 return false
func _physics_process(delta: float):
 if not enabled() or not host.starting_magic.world_active():return
 var s:=state();State.advance(s,delta,submerged());host.quest_state.l9_flood=s
 if s.dead:
  host.starting_magic.set_health(0);host.save_feedback("You drowned. F9 loads your earned save.")
func _process(_delta: float):
 visible=enabled()
 if not visible:return
 for i in surfaces.size():surfaces[i].position.y=State.height(rows[i].source,float(state().elapsed))+0.02
