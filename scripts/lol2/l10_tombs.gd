extends Node3D
const State=preload("res://scripts/lol2/l10_tomb_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
var host: Node3D
var panels: Dictionary={}
var bodies: Dictionary={}
var receptacles: Dictionary={}
const AIM_LAYER:=1<<10
var aims: Dictionary={}
var hint: Label
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_tombs.gd").new()
 node.host=map;node.name="L10Tombs";map.add_child(node);return node
func _ready():
 var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
 var boxes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json")).boxes
 var placements: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/static_assemblies/L10_DC/assemblies.json")).placements
 var materials: Dictionary={}
 for target in State.ROWS:
  var door: int=State.ROWS[target][0]
  var panel:=Node3D.new();add_child(panel);panels[target]=panel
  var body=Assemblies.box_body(door,boxes[str(door)],Vector3.ZERO)
  add_child(body);bodies[target]=body
  var anchor: Dictionary=placements[target]
  aims[target]=Vector3(anchor.x,anchor.height+45,-anchor.y)
  # Raised blue154 sits in a22-high recess: the old+45 ray hit the lintel above its36-high plate.
  if target=="154":aims[target].y=float(boxes[target].h)+float(boxes[target].height)/2
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
  for face in pack.faces:
   if face.get("placement_kind")!="static_assembly" or int(face.get("source_index",-1))!=door:continue
   var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   for i in [0,1,2,0,2,3]:
    surface.set_uv(Vector2(face.uv[i][0],face.uv[i][1]))
    surface.add_vertex(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
   surface.generate_normals()
   var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit()
   if not materials.has(face.material):
    var material:=StandardMaterial3D.new()
    material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[face.material]))
    material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;materials[face.material]=material
   mesh.material_override=materials[face.material];panel.add_child(mesh)
 host.player.collision_mask|=Assemblies.SCENERY_LAYER
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,390);canvas.add_child(hint)
 restore()
func state()->Dictionary:return host.quest_state.get("l10_tombs",State.initial())
func opened(target: String)->bool:return state().slots.get(target,{}).get("committed",false)
func restore():
 for target in panels:
  # Instant upward withdrawal is authored motion, not a decoded selector pose.
  panels[target].position.y=110 if opened(target) else 0
  bodies[target].collision_layer=0 if opened(target) else Assemblies.SCENERY_LAYER
func reachable(target: String)->bool:
 if not aims.has(target):return false
 var delta: Vector3=aims[target]-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray=PhysicsRayQueryParameters3D.create(host.camera.global_position,aims[target],1|AIM_LAYER,[host.player.get_rid()])
 var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.collider==receptacles[target]
func offer(target: String,item: String)->Dictionary:
 if not reachable(target):return {"ok":false,"reason":"Approach and face the receptacle."}
 var result:=State.offer(state(),host.carried_collected,target,item)
 if not result.ok:return result
 host.quest_state.l10_tombs=result.state;host.carried_collected=result.inventory
 Items.sync(host);restore();return result
func target()->String:
 for id in aims:
  if not opened(id) and reachable(id):return id
 return ""
func _process(_delta):
 restore();hint.text=""
 if get_tree().paused or host.flying:return
 var id:=target()
 if not id.is_empty():hint.text="E — Offer a matching charged globe"
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var id:=target()
 if id.is_empty():return
 var item:=""
 for carried in host.carried_collected:
  if Items.definition(carried)==State.ROWS[id][1]:item=carried;break
 var result:=offer(id,item)
 host.save_feedback("The tomb opens." if result.ok else result.reason)
 get_viewport().set_input_as_handled()
