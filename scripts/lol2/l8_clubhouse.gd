extends Node3D
const KEY:="l8_clubhouse"
const Tribe=preload("res://scripts/lol2/l8_tribe_state.gd")
const STONES:=["act2:L8_SJ:item32","act2:L8_SJ:item33","act2:L8_SJ:item34"]
const AIM:=Vector3(-1791,55,1068)
var host:Node3D
var hint:Label
var doors:Dictionary={}
var children:Dictionary={}
static func initial()->Dictionary:return {"version":1,"opened":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("opened") is bool:return "Invalid clubhouse state."
 if s.opened and not Tribe.member(quests.get(Tribe.KEY,{})):return "Clubhouse needs earned membership."
 for id in STONES:
  if id in quests.get("act2_items",{}).get("collected",[]) and not s.opened:return "Clubhouse stone without admission."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l8_clubhouse.gd").new();n.host=map;n.name="L8Clubhouse";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint)
 build_doors()
 restore()
func restore_guard():
 var pop=host.act2_creatures
 if not pop.state.actors["21"].present and (state().opened or host.player.position.distance_to(Vector3(-1791,32,1068))<300):
  pop.State.spawn(pop.state,"21");pop.sync_quests();pop.present()
func restore():
 restore_guard()
 for id in doors:
  var angle:float=-float(host.progression.native.attributes["movable:%d"%id].angle_word)/65536.0*TAU if state().opened else 0.0
  if id==52:angle=-angle
  doors[id].rotation.y=angle
  var rotation:=Basis(Vector3.UP,angle)
  for row in children[id]:
   var entry:Array=host.prop_placements[row]
   var position:Vector3=doors[id].position+rotation*(entry[2]-doors[id].position)
   entry[0].set_instance_transform(entry[1],Transform3D(Basis(),position))
func build_doors():
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for id in [51,52]:
  var raw:PackedByteArray=host.progression.native.placements["movable:%d"%id]
  var origin:=Vector3(raw.decode_s16(0),raw.decode_s16(6),-raw.decode_s16(2))
  var body:=AnimatableBody3D.new();body.position=origin;body.collision_layer=1;body.collision_mask=0;body.sync_to_physics=false
  body.name="OriginalDoor%d"%id;add_child(body);doors[id]=body;children[id]=[]
  var bounds:=AABB();var first:=true
  for row in pack.props.size():
   var prop:Dictionary=pack.props[row]
   if int(prop.get("placement",-1))!=id or not str(prop.material).begins_with("attached_prop_"):continue
   children[id].append(-1-row)
   for point in prop.points:
    var v:=Vector3(point[0],point[1],point[2])-origin
    if first:bounds=AABB(v,Vector3.ZERO);first=false
    else:bounds=bounds.expand(v)
  assert(not first,"Clubhouse source door children missing")
  var pivot:=Vector3(bounds.end.x if id==51 else bounds.position.x,0,0)
  body.position+=pivot
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=bounds.size.max(Vector3(1,1,2));shape.shape=box;shape.position=bounds.get_center()-pivot;body.add_child(shape)
func available()->bool:return not get_tree().paused and not host.flying and host.player_form==0 and host.starting_magic.world_active()
func reachable()->bool:
 var delta:Vector3=AIM-host.camera.global_position
 if delta.length()>160 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,AIM,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func interact()->Dictionary:
 if not available() or not reachable():return {"ok":false,"reason":"Approach the clubhouse guard in human form."}
 if not Tribe.member(host.quest_state.get(Tribe.KEY,{})):return {"ok":false,"reason":"The clubhouse is reserved for members of the tribe."}
 if state().opened:return {"ok":false,"reason":"The clubhouse is already open."}
 host.quest_state[KEY]={"version":1,"opened":true};restore()
 return {"ok":true,"reason":"The guard welcomes you as a tribe member and opens the clubhouse. The Ancients' Stones inside are yours to take."}
func _process(_delta):
 restore_guard()
 hint.text="E — Speak to the clubhouse guard" if available() and reachable() and not state().opened else ""
func _unhandled_input(event:InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if not available() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory) or not reachable():return
 var result:=interact();host.save_feedback(result.reason);get_viewport().set_input_as_handled()
