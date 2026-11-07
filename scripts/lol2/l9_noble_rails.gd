extends Node3D
## Source Noble rail1 controls478..480: kind5 groups17302/17320/17338 select1.
## Landed melee admission and persistent break state are book-led modern adapters.
const IDS:=[478,479,480]
const KEY:="l9_noble_rails"
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
var host: Node3D
var bodies: Dictionary={}
var presented: Array=[]
static func initial()->Dictionary:return {"version":1,"broken":[]}
static func validate(value: Variant)->String:
 if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("broken") is Array:return "Invalid Noble rail state."
 var seen: Dictionary={}
 for id in value.broken:
  if not id is String or id not in ["478","479","480"] or seen.has(id):return "Invalid Noble rail identity."
  seen[id]=true
 return ""
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_noble_rails.gd").new();node.host=map;node.name="L9NobleRails";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L9_DR.json"))
 for id in IDS:
  var body=Assemblies.box_body(id,source.boxes[str(id)],Vector3.ZERO)
  add_child(body);bodies[id]=body
  host.preview_assemblies.stateful_meshes[id]=[]
 # Source bridge471 has events but stands in its initial selector until hit.
 host.preview_assemblies.add_scripted_solids("L9_DR",[471])
 host.player.collision_mask|=Assemblies.SCENERY_LAYER
 restore(true)
func restore(force: bool=false):
 if not force and presented==state().broken:return
 presented=state().broken.duplicate()
 for id in IDS:
  var broken: bool=str(id) in presented
  host.preview_assemblies.set_mode(id,1 if broken else 0)
  bodies[id].collision_layer=0 if broken else Assemblies.SCENERY_LAYER
func strike()->bool:
 if get_tree().paused or host.flying or not host.starting_magic.world_active() or host.player_form==2:return false
 if host.has_method("actor_input_locked") and host.actor_input_locked():return false
 var origin: Vector3=host.camera.global_position
 var ray:=PhysicsRayQueryParameters3D.create(origin,origin-host.camera.global_basis.z*96,1|Assemblies.SCENERY_LAYER,[host.player.get_rid()])
 var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 if hit.is_empty():return false
 for id in IDS:
  if hit.collider!=bodies[id] or str(id) in state().broken:continue
  var next:=state().duplicate(true);next.broken.append(str(id));host.quest_state[KEY]=next;restore()
  host.save_feedback("The rail breaks.");return true
 return false
func _process(_delta):restore()
func _unhandled_input(event: InputEvent):
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not is_instance_valid(host.inventory) and strike():get_viewport().set_input_as_handled()
