extends Node3D
## Known book sigil gate; original control70 and leaves72/73, shared mover presentation.
const KEY := "l10_main_gate"
const SIGIL := "l8:shaman:Dracoid_sigil"
const AIM := Vector3(-125,46,-995)
var host: Node3D
var hint: Label
var panel: Node3D
var panel_body: StaticBody3D
static func initial()->Dictionary:return {"version":1,"open":false}
static func validate(value: Variant)->String:
 return "" if value is Dictionary and value.size()==2 and value.get("version")==1 and value.get("open") is bool else "Invalid Cemetery gate state."
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_main_gate.gd").new()
 node.host=map;node.name="L10MainGate";map.add_child(node);return node
func _ready():
 panel=Node3D.new();panel.name="SigilPanel";add_child(panel)
 panel_body=StaticBody3D.new();panel_body.collision_layer=1;panel.add_child(panel_body)
 var pack:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 for face in pack.faces:
  if face.get("placement_kind")!="static_assembly" or face.get("source_index")!=70:continue
  var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in [0,1,2,0,2,3]:
   surface.set_uv(Vector2(face.uv[i][0],face.uv[i][1]))
   surface.add_vertex(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
  surface.generate_normals()
  var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit()
  var material:=StandardMaterial3D.new()
  material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[face.material]))
  material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
  mesh.material_override=material;panel.add_child(mesh)
  var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();panel_body.add_child(shape)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,360);canvas.add_child(hint)
func opened()->bool:return host.quest_state.get(KEY,initial()).open
func reachable()->bool:
 var delta:Vector3=AIM-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray=PhysicsRayQueryParameters3D.create(host.camera.global_position,AIM,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func unlock(item: String)->Dictionary:
 if not reachable():return {"ok":false,"reason":"Approach the gate."}
 if opened():return {"ok":false,"reason":"The gate is already open."}
 if item!=SIGIL or item not in host.carried_collected:return {"ok":false,"reason":"The Dracoid Sigil opens this gate."}
 # Books do not specify consumption. Preserve the key (documented adapter), never replay native take-item.
 host.quest_state[KEY]={"version":1,"open":true}
 restore()
 return {"ok":true}
func restore():
 panel.visible=not opened()
 panel_body.collision_layer=0 if opened() else 1
 if host.progression==null:return
 var binder=host.progression
 for id in [70,71,72,73]:
  var attrs:Dictionary=binder.native.attributes.get("movable:%d"%id,{})
  binder.travel[id]=(int(attrs.get("angle_word",0))&0xffff) if opened() else 0
  # These four pieces form two horizontal halves; the generic vertical-panel adapter
  # leaves the upper latch across the doorway. Keep the source 132 travel extent.
  var target:=Transform3D(Basis(),binder.hinge_origin[id])
  if opened():target.origin.x+=(-1.0 if id in [70,73] else 1.0)*absf(float(attrs.get("angle_word",132)))
  binder.mover_targets[id]=target
func _process(_delta):
 restore()
 hint.text="E — Unlock with the Dracoid Sigil" if not get_tree().paused and not host.flying and not opened() and reachable() else ""
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 if not reachable() or opened():return
 var result:=unlock(SIGIL)
 host.save_feedback("The Cemetery gate opens." if result.ok else result.reason)
 get_viewport().set_input_as_handled()
