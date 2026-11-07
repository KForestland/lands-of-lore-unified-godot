extends Node3D
## Original body2406, pyre301 children223/225/224 and orb1205/1206; book-led action admission.
const State=preload("res://scripts/lol2/l9_pyre_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY:="l9_pyre"
const MEDIA:="res://assets/lol2/generated/l9_pyre/"
const ALTAR:=Vector3(10884.828369,140,-12566.17163)
const ORBS:={"1205":Vector3(10737,169,-12586),"1206":Vector3(10871,169,-12711)}
var host: Node3D
var source: Dictionary
var meshes: Dictionary={}
var materials: Dictionary={}
var fire_frames: Array[Texture2D]=[]
var hint: Label
class Receiver extends RefCounted:
 var owner_node: Node
 var id: String
 func _init(node: Node,key: String):owner_node=node;id=key
 func receive_spark()->bool:return owner_node.ignite(id)
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_pyre.gd").new();node.host=map;node.name="L9Pyre";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(KEY,State.initial())
func body_position()->Vector3:
 var p: Array=state().body;return Vector3(p[0],p[1],p[2])
func _ready():
 source=JSON.parse_string(FileAccess.get_file_as_string(MEDIA+"pyre.json"))
 for row in source.state_props:
  var id:=str(int(row.child));var at: Array=row.position
  add_sprite(id,row,MEDIA+source.materials[row.material],Vector3(at[0],at[1],at[2]))
 for file in source.animations.attached_prop_631.frames:fire_frames.append(ImageTexture.create_from_image(Image.load_from_file(MEDIA+file)))
 for id in ORBS:
  var row: Dictionary=source.orb.visuals["0"]
  var sprite_row: Dictionary=row.duplicate(true);sprite_row.top=58.0
  add_sprite(id,sprite_row,MEDIA+"orb/"+source.orb.materials[row.material],ORBS[id]-Vector3.UP*29)
  var receiver:=StaticBody3D.new();receiver.position=ORBS[id];receiver.collision_layer=1;receiver.collision_mask=0;receiver.set_meta("spark_receiver",Receiver.new(self,id))
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(26,58,20);shape.shape=box;receiver.add_child(shape);add_child(receiver)
 for id in [2406,1205,1206]:
  if host.prop_placements.has(id):
   var row: Array=host.prop_placements[id];row[0].set_instance_transform(row[1],Transform3D(Basis().scaled(Vector3.ZERO),row[2]))
 var full:=Sprite3D.new();full.texture=ImageTexture.create_from_image(Image.load_from_file(Items.row(State.FULL).icon));full.pixel_size=0.5;full.position=ALTAR+Vector3.UP*12;full.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;full.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(full);meshes["urn"]=full
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,420);canvas.add_child(hint)
 present()
func add_sprite(id: String,row: Dictionary,file: String,at: Vector3):
 var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(file));material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 var quad:=QuadMesh.new();quad.size=Vector2(row.right-row.left,row.top-row.bottom);quad.center_offset=Vector3((row.left+row.right)/2,(row.bottom+row.top)/2,0)
 var mesh:=MeshInstance3D.new();mesh.mesh=quad;mesh.material_override=material;mesh.position=at;add_child(mesh);meshes[id]=mesh;materials[id]=material
func world_active()->bool:return not get_tree().paused and not host.flying and host.starting_magic.world_active() and not (host.has_method("actor_input_locked") and host.actor_input_locked())
func active()->bool:return world_active() and host.player_form==0
func reachable(point: Vector3)->bool:
 var delta: Vector3=point-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func grab()->Dictionary:
 if not active() or state().phase!=0 or state().holding or not reachable(body_position()+Vector3.UP*10):return {"ok":false,"reason":"Approach the body."}
 var next:=state().duplicate(true);next.holding=true;host.quest_state[KEY]=next;return {"ok":true,"reason":"Drag the body to the pyre."}
func place()->Dictionary:
 if not active() or state().phase!=0 or not state().holding or not reachable(ALTAR+Vector3.UP*12) or body_position().distance_to(ALTAR)>100:return {"ok":false,"reason":"Bring the body close to the pyre."}
 var result:=State.place_body(state(),[ALTAR.x,ALTAR.y,ALTAR.z])
 if not result.ok:return result
 host.quest_state[KEY]=result.state;present();return {"ok":true,"reason":"The body rests on the pyre."}

func ignite(id: String)->bool:
 if not active() or state().phase!=1 or id not in ORBS or id in state().orbs:return false
 var next:=state().duplicate(true);next.orbs.append(id)
 if next.orbs.size()==2:next.phase=2
 host.quest_state[KEY]=next;present();return true
func urn(action: String,item: String="")->Dictionary:
 if not active() or not reachable(ALTAR+Vector3.UP*12):return {"ok":false,"reason":"Approach and face the ashes."}
 var result:=State.act(state(),host.carried_collected,action,item)
 if not result.ok:return result
 host.quest_state[KEY]=result.state;host.carried_collected=result.inventory
 var packet: Dictionary=host.quest_state.get("act2_items",Items.initial()).duplicate(true)
 if State.FULL not in packet.collected:packet.collected.append(State.FULL)
 host.quest_state.act2_items=packet;Items.sync(host);host.act2_items.restore();present()
 return {"ok":true,"reason":"The urn holds the priest's ashes."}
func present():
 var s:=state()
 meshes["urn"].visible=s.slots.get(State.TARGET,{}).get("occupied","")==State.FULL
 meshes["223"].position=body_position();meshes["223"].visible=s.phase<2
 meshes["225"].visible=s.phase==2;meshes["224"].visible=s.phase==3 and not s.slots.get(State.TARGET,{}).get("committed",false)
 if s.phase==2:materials["225"].albedo_texture=fire_frames[mini(fire_frames.size()-1,int(s.burn*10))]
 for id in ORBS:
  var selector:="1" if id in s.orbs else "0";var row: Dictionary=source.orb.visuals[selector]
  if materials[id].get_meta("selector","")!=selector:
   materials[id].albedo_texture=ImageTexture.create_from_image(Image.load_from_file(MEDIA+"orb/"+source.orb.materials[row.material]));materials[id].set_meta("selector",selector)
func _physics_process(delta: float):
 if not world_active():return
 var s:=state().duplicate(true)
 if host.player_form!=0:s.holding=false
 if s.holding:
  var target: Vector3=host.player.position+host.camera.global_basis.z*35;target.y=host.player.position.y-32
  var old:=body_position();var next:=old.move_toward(target,120*delta)
  var ray:=PhysicsRayQueryParameters3D.create(old+Vector3.UP*10,next+Vector3.UP*10,1,[host.player.get_rid()])
  if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and absf(next.x-10800)<=1500 and absf(next.z+12800)<=1500 and next.y>=100 and next.y<=300:s.body=[next.x,next.y,next.z]
 if s.phase==2:
  s.burn=minf(State.DURATION,float(s.burn)+delta)
  if s.burn>=State.DURATION:s.phase=3
 if s!=state():host.quest_state[KEY]=s
func _process(_delta):
 present();hint.text=""
 if not active():return
 if state().phase==0 and not state().holding and reachable(body_position()+Vector3.UP*10):hint.text="E — Drag the body"
 elif state().holding and reachable(ALTAR+Vector3.UP*12):hint.text="E — Lay the body on the pyre"
 elif state().phase==3 and reachable(ALTAR+Vector3.UP*12):hint.text="E — Take filled urn" if not state().slots.get(State.TARGET,{}).get("occupied","").is_empty() else "E — Fill urn with ashes"
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E or not active() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 var result: Dictionary
 if state().phase==0:result=place() if state().holding else grab()
 elif state().phase==3:
  var occupied: String=state().slots.get(State.TARGET,{}).get("occupied","");result=urn("retrieve") if not occupied.is_empty() else urn("insert",State.URN)
 else:return
 if result.ok:host.save_feedback(result.reason);get_viewport().set_input_as_handled()
