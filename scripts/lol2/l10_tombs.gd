extends Node3D
const Grants=preload("res://scripts/lol2/item_grants.gd")
const State=preload("res://scripts/lol2/l10_tomb_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
const GLOWS := {"158":81,"152":80,"161":82,"164":64,"87":76,"91":63,"95":79,"99":83,"105":77,"108":78,"154":68,"156":84,"109":69}
var host: Node3D
var renderer: Node3D
var shown: Dictionary={}
var bodies: Dictionary={}
var receptacles: Dictionary={}
const AIM_LAYER:=1<<10
var aims: Dictionary={}
var hint: Label
static func owns(face: Dictionary)->bool:
 if face.get("placement_kind")!="static_assembly":return false
 var id:int=int(face.get("source_index",-1))
 return State.ROWS.has(str(id)) or id in State.doors() or id in GLOWS.values()
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_tombs.gd").new()
 node.host=map;node.name="L10Tombs";map.add_child(node);return node
func _ready():
 var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 var boxes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json")).boxes
 var placements: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/static_assemblies/L10_DC/assemblies.json")).placements
 renderer=Assemblies.new();add_child(renderer)
 var managed:Array=State.doors()+GLOWS.values()
 for id in State.ROWS:managed.append(int(id))
 var render_error:String=renderer.setup_selected(host,"L10_DC",managed)
 assert(render_error.is_empty(),render_error)
 for target in State.ROWS:
  var door: int=State.ROWS[target][0]
  var body=Assemblies.box_body(door,boxes[str(door)],Vector3.ZERO)
  add_child(body);bodies[target]=body
  var anchor: Dictionary=placements[target]
  aims[target]=Vector3(anchor.x,anchor.height+45,-anchor.y)
  # Raised blue154 sits in a22-high recess: the old+45 ray hit the lintel above its36-high plate.
  if boxes.has(target):aims[target].y=float(boxes[target].h)+float(boxes[target].height)/2
  var receptacle: StaticBody3D
  if boxes.has(target):
   receptacle=Assemblies.box_body(int(target),boxes[target],Vector3.ZERO)
   receptacle.collision_layer|=AIM_LAYER
  else:
   receptacle=StaticBody3D.new();receptacle.collision_layer=AIM_LAYER
   var bounds:=AABB();var first:=true
   for face in pack.faces:
    if face.get("placement_kind")!="static_assembly" or int(face.get("source_index",-1))!=int(target):continue
    for point in face.points:
     var v:=Vector3(point[0],point[1],point[2])
     if first:bounds=AABB(v,Vector3.ZERO);first=false
     else:bounds=bounds.expand(v)
   var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
   box.size=bounds.size.max(Vector3.ONE);shape.shape=box;shape.position=bounds.get_center();receptacle.add_child(shape)
  add_child(receptacle);receptacles[target]=receptacle
 host.player.collision_mask|=Assemblies.SCENERY_LAYER
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,390);canvas.add_child(hint)
 restore()
func state()->Dictionary:return host.quest_state.get("l10_tombs",State.initial())
func opened(target: String)->bool:return state().slots.get(target,{}).get("committed",false)
func restore():
 for target in State.ROWS:
  var is_open:bool=opened(target)
  if shown.get(target,-1)==int(is_open):continue
  shown[target]=int(is_open)
  # Native door selector2 and solid-bit clear; no upward panel-lift adapter.
  renderer.set_mode(int(State.ROWS[target][0]),2 if is_open else 0)
  bodies[target].collision_layer=0 if is_open else Assemblies.SCENERY_LAYER
  var selector:int={99:2,100:1,101:3}[int(State.ROWS[target][1])]
  renderer.set_mode(int(target),selector if is_open else 0)
  # Modern on-state adapter: the original caller20 producer is unknown; show its published colour frame steadily.
  renderer.set_mode(int(GLOWS[target]),0 if is_open else 1)
func reachable(target: String)->bool:
 if not aims.has(target):return false
 # Lead replacement after R106: same crosshair and occlusion rule as lids.
 var hit:Dictionary=preload("res://scripts/lol2/player_combat.gd").aim_ray(host,256.0,1|2|AIM_LAYER)
 return not hit.is_empty() and hit.collider==receptacles[target]
func offer(target: String,item: String)->Dictionary:
 if not reachable(target):return {"ok":false,"reason":"Move within reach of the receptacle."}
 var result:=State.offer(state(),host.carried_collected,target,item)
 if not result.ok:return result
 var admission:=Grants.transition(host,result.inventory,{"l10_tombs":result.state})
 if not admission.ok:return admission
 Items.sync(host);restore();return result
func target()->String:
 var best:="";var distance:=INF
 for id in aims:
  if not opened(id) and reachable(id):
   var length:float=aims[id].distance_to(host.camera.global_position)
   if length<distance:best=id;distance=length
 return best
func _process(_delta):
 restore();hint.text=""
 if get_tree().paused or host.flying or host.player_form!=0:return
 var id:=target()
 if not id.is_empty():hint.text="E — Offer a %s globe"%{99:"yellow",100:"white",101:"blue"}[int(State.ROWS[id][1])]
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 if try_use():get_viewport().set_input_as_handled()
func try_use(target_id:String="")->bool:
 var id:String=target() if target_id.is_empty() else target_id
 if id.is_empty() or not reachable(id) or host.player_form!=0:return false
 var item:=""
 for carried in host.carried_collected:
  if Items.definition(carried)==State.ROWS[id][1]:item=carried;break
 var result:=offer(id,item)
 host.save_feedback("The tomb opens." if result.ok else result.reason)
 return true
