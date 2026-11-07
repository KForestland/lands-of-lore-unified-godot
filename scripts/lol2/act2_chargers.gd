extends Node3D
## Book behaviour, source prop anchors; authored E interaction and occupied-globe display.
const State = preload("res://scripts/lol2/act2_charger_state.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const ANCHORS := {"L10:yellow":Vector3(1152,-121,-3632),"L10:blue":Vector3(-1456,-121,-4959),"L9:white":Vector3(-3656,150,-833)}
const AREAS := {"L10:yellow":"L10_DC","L10:blue":"L10_DC","L9:white":"L9_DR"}
var host: Node3D
var area := ""
var globes: Dictionary = {}
var hint: Label
static func attach(map: Node3D, level: String) -> Node3D:
 if level not in ["L10_DC","L9_DR"]: return null
 var node = load("res://scripts/lol2/act2_chargers.gd").new()
 node.host=map;node.area=level;node.name="Act2Chargers"
 map.add_child(node)
 return node
func _ready():
 for id in ANCHORS:
  if AREAS[id]!=area: continue
  var sphere := MeshInstance3D.new()
  var mesh := SphereMesh.new()
  mesh.radius=7;mesh.height=14
  sphere.mesh=mesh
  var material := StandardMaterial3D.new()
  material.albedo_color={"L10:yellow":Color.GOLD,"L10:blue":Color.DODGER_BLUE,"L9:white":Color.WHITE}[id]
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  sphere.material_override=material
  sphere.position=ANCHORS[id]+Vector3.UP*8+(host.get("native_translation") if host.get("native_translation")!=null else Vector3.ZERO)
  add_child(sphere);globes[id]=sphere
 var canvas := CanvasLayer.new()
 canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,330);canvas.add_child(hint)
 restore()
func state() -> Dictionary: return host.quest_state.get("act2_chargers",State.initial())
func restore():
 for id in globes:
  globes[id].visible=not state().slots.get(id,{}).get("occupied","").is_empty()
func reachable(id: String) -> bool:
 if not globes.has(id): return false
 var point: Vector3=globes[id].global_position
 var delta: Vector3=point-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01: return false
 if (-host.camera.global_basis.z).dot(delta.normalized())<0.8: return false
 var ray=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func target() -> String:
 for id in globes:
  if reachable(id): return id
 return ""
func interact(id: String, action: String, item: String="") -> Dictionary:
 if not reachable(id): return {"ok":false,"reason":"Move closer and face the altar."}
 var result := State.act(state(),host.carried_collected,id,action,item)
 if not result.ok:return result
 host.quest_state.act2_chargers=result.state
 host.carried_collected=result.inventory
 Items.sync(host)
 restore()
 return result
func _process(_delta):
 restore()
 hint.text=""
 if get_tree().paused or host.flying: return
 var id:=target()
 if id.is_empty():return
 hint.text="E — Retrieve charged globe" if globes[id].visible else "E — Place an empty glass globe"
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var id:=target()
 if id.is_empty():return
 var item:=""
 for carried in host.carried_collected:
  if Items.definition(carried)==98:item=carried;break
 var result:=interact(id,"retrieve" if globes[id].visible else "insert",item)
 host.save_feedback("Globe retrieved." if result.ok and not globes[id].visible else ("Globe charged." if result.ok else result.reason))
 get_viewport().set_input_as_handled()
