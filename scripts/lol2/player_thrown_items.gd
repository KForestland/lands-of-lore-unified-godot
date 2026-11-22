extends Node3D
const Rules=preload("res://scripts/lol2/item_throw_rules.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
var controller:Node
var host:Node3D
var cooldown:=0.0
var sprites:Dictionary={}
var hint:Label
func setup(owner:Node):
 controller=owner;host=owner.host
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas)
 hint=Label.new();hint.position=Vector2(24,480);canvas.add_child(hint)
func rows()->Array:return controller.state().get("thrown_items",[])
func ready_to_use()->bool:
 return is_instance_valid(host.starting_magic) and host.starting_magic.available() and host.player_form==0 and not controller.is_asleep()
func floor_at(point:Vector3)->Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*12,point+Vector3.DOWN*256,1,[host.player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(query)
func throw_item(id:String)->bool:
 if not ready_to_use() or cooldown>0 or host.scene_file_path not in Rules.AREAS or id not in controller.carried():return false
 if not Rules.supported(Catalog.definition(id)) or not controller.can_consume(id):return false
 var protected:String=preload("res://scripts/lol2/quest_resource_protection.gd").removing(host,controller.carried(),id)
 if not protected.is_empty():return controller.refuse_item(protected)
 var origin:Vector3=host.camera.global_position
 var end:Vector3=origin-host.camera.global_basis.z*Rules.REACH
 var ray:=PhysicsRayQueryParameters3D.create(origin,end,3,[host.player.get_rid()]);ray.hit_from_inside=true
 var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
 if not hit.is_empty():end=hit.position+hit.normal*3
 var returning:bool=Catalog.definition(id)==6
 var ground:Dictionary={}
 if not returning:
  ground=floor_at(end)
  if ground.is_empty():host.save_feedback("There is no safe ground to recover it. The item is kept.");return false
  if not controller.consume_item(id):return false
  if not controller.state().has("thrown_items"):controller.state().thrown_items=[]
  var at:Vector3=ground.position+Vector3.UP*4
  controller.state().thrown_items.append({"id":id,"area":host.scene_file_path,"position":[at.x,at.y,at.z]})
  if host.get("equipped_item")==id:host.set_equipped_item("")
 cooldown=preload("res://scripts/lol2/player_combat.gd").COOLDOWN
 # Commit ownership before any hit callback can save or transition the area.
 if not hit.is_empty():strike(hit.collider,id)
 animate_item(id,origin,end,returning)
 host.save_feedback("Long Arm returns to your hand." if returning else "Thrown. Press E near the item to take it back.")
 return true
func strike(body:Object,item:String)->void:
 var damage:int=Rules.DAMAGE
 var targets:Dictionary=host.starting_magic.aura.targets()
 for key in targets:
  var target:Dictionary=targets[key]
  if target.body!=body:continue
  # Physical throws use existing fighting rewards, not Spark/magic awards.
  if target.has("owner"):target.owner.receive_damage(str(target.actor),damage,true)
  elif key=="roach23":host.roach.receive_strike(true,true,true,damage)
  elif key=="executioner36":host.executioner_live.receive_strike(damage,true)
  elif target.has("index"):host.get_node("Warriors").damage_guardian(int(target.index),damage)
  return
func animate_item(id:String,origin:Vector3,end:Vector3,returning:bool):
 var sprite:=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(Catalog.icon(id)));sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.pixel_size=0.35;add_child(sprite);sprite.global_position=origin
 var tween:=create_tween();tween.tween_property(sprite,"global_position",end,0.18)
 if returning:tween.tween_property(sprite,"global_position",origin,0.18)
 tween.tween_callback(sprite.queue_free)
func pickup_target()->String:
 if not ready_to_use():return ""
 for row in rows():
  if row.area!=host.scene_file_path:continue
  var p:Vector3=Vector3(row.position[0],row.position[1],row.position[2])
  var delta:Vector3=p-host.camera.global_position
  if delta.length()>96 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:continue
  var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,p,1,[host.player.get_rid()])
  var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty() or hit.position.distance_to(p)<6:return row.id
 return ""
func take(id:String)->bool:
 if id!=pickup_target() or not Grants.room(host):return false
 var rows_before:Array=rows().duplicate(true);var spent_before:Array=controller.state().spent.duplicate()
 controller.state().thrown_items=rows().filter(func(row):return row.id!=id)
 controller.state().spent.erase(id)
 var result:Dictionary=Grants.grant(host,id,{"cap":true,"full_text":"Your inventory is full.","sync":host.get("carried_collected") is Array})
 if not result.ok:
  controller.state().thrown_items=rows_before;controller.state().spent=spent_before;return false
 host.save_feedback("Taken: "+Catalog.label(id));present();return true
func present():
 var active:Array=[]
 for row in rows():
  if row.area!=host.scene_file_path:continue
  active.append(row.id)
  if not sprites.has(row.id):
   var sprite:=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(Catalog.icon(row.id)));sprite.pixel_size=0.5;sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;add_child(sprite);sprites[row.id]=sprite
   var at:=Vector3(row.position[0],row.position[1],row.position[2]);sprite.global_position=at
   bind_room(sprite,at)
  sprites[row.id].global_position=Vector3(row.position[0],row.position[1],row.position[2])
 for id in sprites.keys():
  if id not in active:sprites[id].queue_free();sprites.erase(id)
func bind_room(sprite:Sprite3D,point:Vector3):
 var Rooms=load("res://scripts/lol2/object_room_visibility.gd")
 if not Rooms.enabled(host):return
 var nav:Variant=host.get("portal_nav")
 if not nav is Array:return
 var best:=-1;var floor_height:=-INF
 for index in nav.size():
  var row:Array=nav[index]
  if row.size()<2 or float(row[1])>point.y+1 or float(row[1])<=floor_height:continue
  var poly:=PackedVector2Array()
  for p in row[0]:poly.append(Vector2(p[0],p[1]))
  if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),poly):best=index;floor_height=float(row[1])
 if best>=0:
  var placement:=PackedByteArray();placement.resize(12);placement.encode_u16(10,best)
  Rooms.bind(host,sprite,placement)
 else:sprite.visible=false
func _process(delta:float):
 if not is_instance_valid(host) or not is_instance_valid(host.starting_magic):return
 if host.starting_magic.world_active():cooldown=maxf(0,cooldown-delta)
 present();hint.text=""
 var target:String=pickup_target()
 if not target.is_empty():hint.text="E — Take "+Catalog.label(target)
 elif ready_to_use() and Rules.supported(Catalog.definition(host.get("hand_item"))):hint.text="Right click — Throw "+Catalog.label(host.hand_item)
func _unhandled_input(event:InputEvent):
 if not ready_to_use() or (DisplayServer.get_name()!="headless" and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED):return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if throw_item(str(host.get("hand_item"))):get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
  var target:String=pickup_target()
  if not target.is_empty() and take(target):get_viewport().set_input_as_handled()
