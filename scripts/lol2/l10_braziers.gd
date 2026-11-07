extends Node3D
## STORY-008: original template23 basket and selector1 sprites; modern E ignition.
const KEY:="l10_braziers"
var host: Node3D
var flames: Dictionary={}
var aims: Dictionary={}
var frames: Array[Texture2D]=[]
var material: StandardMaterial3D
var hint: Label
var elapsed:=0.0
static func initial()->Dictionary:return {"version":1,"lit":[]}
static func valid_id(id: Variant)->bool:
 if not id is String or not id.is_valid_int() or id!=str(int(id)):return false
 var n:=int(id)
 return n==153 or (n>=200 and n<=241) or (n>=336 and n<=339)
static func validate(state: Variant)->String:
 if not state is Dictionary or state.size()!=2 or state.get("version")!=1 or not state.get("lit") is Array:return "Invalid Cemetery brazier state."
 var seen:={}
 for id in state.lit:
  if not valid_id(id) or seen.has(id):return "Invalid or duplicate Cemetery brazier."
  seen[id]=true
 return ""
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_braziers.gd").new()
 node.host=map;node.name="L10Braziers";map.add_child(node);return node
func _ready():
 var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for path in pack.animations.prop_219.frames:
  frames.append(ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+path)))
 material=StandardMaterial3D.new();material.albedo_texture=frames[0]
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 for row in pack.props:
  if row.get("template")!=23 or not row.has("record"):continue
  var id:=str(int(row.record))
  assert(valid_id(id))
  var node:=MeshInstance3D.new();var quad:=QuadMesh.new()
  quad.size=Vector2(64,86);quad.center_offset=Vector3(0,43,0);node.mesh=quad
  node.material_override=material;node.position=Vector3(row.position[0],row.position[1],row.position[2])
  add_child(node);flames[id]=node;aims[id]=node.position+Vector3.UP*43
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,420);canvas.add_child(hint)
 restore()
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func lit(id: String)->bool:return id in state().lit
func restore():
 for id in flames:
  flames[id].visible=lit(id)
  var entry: Array=host.prop_placements[int(id)]
  entry[0].set_instance_transform(entry[1],Transform3D(Basis().scaled(Vector3.ZERO) if lit(id) else Basis(),entry[2]))
func reachable(id: String)->bool:
 if not aims.has(id):return false
 var delta: Vector3=aims[id]-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray=PhysicsRayQueryParameters3D.create(host.camera.global_position,aims[id],1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func ignite(id: String)->Dictionary:
 if get_tree().paused or host.flying:return {"ok":false,"reason":"Return to the world first."}
 if not reachable(id):return {"ok":false,"reason":"Approach and face the brazier."}
 if lit(id):return {"ok":false,"reason":"The brazier is already alight."}
 var next:=state().duplicate(true);next.lit.append(id)
 host.quest_state[KEY]=next;restore();return {"ok":true}
func target()->String:
 for id in flames:
  if not lit(id) and reachable(id):return id
 return ""
func _process(delta):
 elapsed+=delta;material.albedo_texture=frames[int(elapsed*10)%frames.size()]
 restore();hint.text=""
 if not get_tree().paused and not host.flying and not target().is_empty():hint.text="E — Light brazier"
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var id:=target()
 if id.is_empty():return
 var result:=ignite(id)
 host.save_feedback("The brazier catches fire." if result.ok else result.reason)
 get_viewport().set_input_as_handled()
