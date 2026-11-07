extends Node3D
## Prima99-100 direction rule, approved lead04:22; original template17 solids.
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
const SIGNS={74:1,75:-1,174:1}
var host: Node3D
var rows: Dictionary={}
var passes:=0
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_fences.gd").new()
 node.host=map;node.name="L10Fences";map.add_child(node);return node
func _ready():
 var boxes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json")).boxes
 for id in SIGNS:
  var source: Dictionary=boxes[str(id)]
  var box: Dictionary=source.duplicate();box.h=float(source.h)-32;box.height=122
  var body=Assemblies.box_body(id,box,Vector3.ZERO);add_child(body)
  if host.preview_assemblies.solid_bodies.has(id):host.preview_assemblies.solid_bodies[id].collision_layer=0
  rows[id]={"body":body,"height":float(source.h),"normal":body.basis.z*SIGNS[id],"center":Vector3(source.x,source.h,-source.y),"width":float(source.width),"high":false,"passing":false}
 host.player.collision_mask|=Assemblies.SCENERY_LAYER
func prepare(direction: Vector3,sprint: bool):
 for id in rows:
  var row: Dictionary=rows[id]
  var delta: Vector3=host.player.position-row.center
  var side: float=delta.dot(row.normal)
  var feet: float=host.player.position.y-32
  # Do not obstruct the separate source floor stacked above this underground fence.
  if feet>row.height+85 or absf(side)>220 or absf(delta.dot(row.body.basis.x))>row.width/2+80:
   row.body.collision_layer=0 if feet>row.height+85 else Assemblies.SCENERY_LAYER
   row.high=false;row.passing=false;continue
  if host.player.is_on_floor():
   row.high=side>8 and absf(feet-row.height)<18
   row.passing=false
  if not row.passing and admits(row.high,host.player.is_on_floor(),sprint,Input.is_physical_key_pressed(KEY_CTRL),direction.dot(row.normal)):
   row.passing=true;passes+=1
  if row.passing and (side < -55 or not sprint or not Input.is_physical_key_pressed(KEY_CTRL) or direction.dot(row.normal)>=0):row.passing=false;row.high=false
  row.body.collision_layer=0 if row.passing else Assemblies.SCENERY_LAYER

func restore():
 for row in rows.values():
  row.high=false;row.passing=false;row.body.collision_layer=Assemblies.SCENERY_LAYER

static func admits(high: bool,grounded: bool,sprint: bool,crouch: bool,direction: float)->bool:
 return high and not grounded and sprint and crouch and direction < -0.5
