extends Node3D
const DeadBracers=preload("res://scripts/lol2/dead_bracers_item.gd")
const State=preload("res://scripts/lol2/l10_emperor_state.gd")
const Assemblies=preload("res://scripts/lol2/static_assemblies.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const OWNED:=[125,126,127,143,175]
const AIMS:={"125":Vector3(3378,-37.5,-1577),"126":Vector3(3208,-37.5,-1577),"127":Vector3(3017,-37.5,-1580),"143":Vector3(3206,0,-1295),"remains":Vector3(3205,-8,-1285)}
var host: Node3D
var renderer: Node3D
var bodies: Dictionary={}
var presented:=""
var hint: Label
var room: CanvasLayer
var room_panel: Control
var room_picture: TextureRect
var room_frames: Array[Texture2D]=[]
var room_elapsed:=0.0
var room_active:=false
static func owns(face: Dictionary)->bool:return face.get("placement_kind")=="static_assembly" and int(face.get("source_index",-1)) in OWNED
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l10_emperor.gd").new();node.host=map;node.name="L10Emperor";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get("l10_emperor",State.initial())
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 renderer=Assemblies.new();renderer.host=host;renderer.data=JSON.parse_string(FileAccess.get_file_as_string(Assemblies.ROOT+"L10_DC/assemblies.json"));add_child(renderer)
 for id in OWNED:
  var faces: Array=[]
  for f in renderer.data.faces:
   if int(f.assembly)==id and f.initial:faces.append(f)
  renderer._build_assembly(id,faces)
  var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var shape:=CollisionShape3D.new();body.add_child(shape);add_child(body);bodies[id]=body
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,450);canvas.add_child(hint)
 setup_room()
 restore()
func restore():
 var s:=state();var signature:=JSON.stringify(s.slots)+str(s.remains)
 if signature==presented:return
 presented=signature
 for id in OWNED:
  var mode:=0
  if id in [125,126,127]:mode=3 if not State.Kit.slot(s,str(id)).occupied.is_empty() else 0
  elif id==175:mode=State.count(s)
  elif id==143:mode=1 if State.opened(s) else 0
  renderer.set_mode(id,mode)
  var points:=PackedVector3Array()
  for face in renderer.data.faces:
   if int(face.assembly)!=id or (int(face.mask)&(1<<mode))==0:continue
   for i in [0,1,2,0,2,3]:points.append(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
  var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points);bodies[id].get_child(0).shape=shape
func active()->bool:return not get_tree().paused and not host.flying and host.player_form==0 and host.starting_magic.world_active()
func reachable(target: String)->bool:
 if target=="remains":
  var p: Vector3=host.player.global_position
  return p.y>=-30 and p.y<=0 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array([Vector2(3154,-1297),Vector2(3256,-1297),Vector2(3256,-1244),Vector2(3154,-1241)]))
 if not AIMS.has(target):return false
 var delta: Vector3=AIMS[target]-host.camera.global_position
 if delta.length()>140 or delta.length()<0.01 or (-host.camera.global_basis.z).dot(delta.normalized())<0.8:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,AIMS[target],1,[host.player.get_rid()])
 var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or (target!="remains" and hit.collider==bodies.get(int(target)))
func interact(target: String,item: String="")->Dictionary:
 if not active() or not reachable(target):return State.Kit.refuse("Approach and face the Emperor's receptacle as Human.")
 if target=="remains":return enter_room()
 var result:=State.act(state(),host.carried_collected,target,item)
 if not result.ok:return result
 host.quest_state.l10_emperor=result.state;host.carried_collected=result.inventory
 if result.state.remains:
  var history: Dictionary=host.quest_state.act2_items.duplicate(true)
  if State.REMAINS not in history.collected:history.collected.append(State.REMAINS)
  host.quest_state.act2_items=history
 Items.sync(host);restore();return {"ok":true,"reason":"You take the Emperor's remains." if target=="remains" else "The tomb mechanism responds."}
func target()->String:
 if State.opened(state()) and reachable("remains"):return "remains"
 for id in AIMS:
  if reachable(id):return id
 return ""
func _process(_delta):
 if room_active:
  room_elapsed+=_delta
  room_picture.texture=room_frames[int(room_elapsed*15)%room_frames.size()]
  var viewport:=get_viewport().get_visible_rect().size
  var scale_value:=minf(viewport.x/640.0,viewport.y/400.0)
  room_panel.scale=Vector2.ONE*scale_value;room_panel.position=(viewport-Vector2(640,400)*scale_value)/2
 restore();hint.text=""
 if active():
  var id:=target()
  if not id.is_empty():hint.text="E — Speak with the Emperor" if id=="remains" else "E — Use the ankh" if id=="143" else "E — Place or retrieve the matching globe"
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if not active() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var id:=target()
 if id.is_empty():return
 var item:=State.Ankh.ANKH if id=="143" else ""
 if State.COLORS.has(id):
  for carried in host.carried_collected:
   if Items.definition(carried)==State.COLORS[id]:item=carried;break
 var result:=interact(id,item);host.save_feedback(result.reason);get_viewport().set_input_as_handled()

func setup_room():
 var root_path:="res://assets/lol2/generated/l10_emperor/"
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path+"emperor.json"))
 for f in data.frames:room_frames.append(ImageTexture.create_from_image(Image.load_from_file(root_path+f.file)))
 room=CanvasLayer.new();room.layer=80;add_child(room)
 var shade:=ColorRect.new();shade.color=Color.BLACK;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);room.add_child(shade)
 room_panel=Control.new();room_panel.size=Vector2(640,400);room.add_child(room_panel)
 room_picture=TextureRect.new();room_picture.size=Vector2(640,400);room_picture.texture=room_frames[0];room_panel.add_child(room_picture)
 var coffin:=Button.new();coffin.name="CoffinHotspot";coffin.position=Vector2(293,102);coffin.size=Vector2(53,144);coffin.flat=true;coffin.tooltip_text="The Emperor's sarcophagus";coffin.pressed.connect(func():var result:=collect_remains();host.save_feedback(result.reason));room_panel.add_child(coffin)
 var label:=Label.new();label.text="E — Take the Emperor's remains     Esc — Leave";label.position=Vector2(110,370);room_panel.add_child(label)
 room.visible=false
func enter_room()->Dictionary:
 if not State.opened(state()):return State.Kit.refuse("The Emperor's tomb is sealed.")
 if not DeadBracers.available(host.carried_collected):return host.get_node("L10Silverleaf").revisit()
 if state().remains:return State.Kit.refuse("You already received the Emperor's remains.")
 room_active=true;room.visible=true;room_elapsed=0;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 return {"ok":true,"reason":"The Emperor asks you to carry his remains to the ruins."}
func leave_room():
 room_active=false;room.visible=false;get_tree().paused=false
 if DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func collect_remains()->Dictionary:
 if not room_active:return State.Kit.refuse("Enter the Emperor's tomb first.")
 var result:=State.take(state(),host.carried_collected)
 if not result.ok:return result
 host.quest_state.l10_emperor=result.state;host.carried_collected=result.inventory
 var history: Dictionary=host.quest_state.act2_items.duplicate(true)
 if State.REMAINS not in history.collected:history.collected.append(State.REMAINS)
 host.quest_state.act2_items=history;Items.sync(host);leave_room();restore()
 return {"ok":true,"reason":"You take the Emperor's remains."}
func _input(event: InputEvent):
 if not room_active or event is not InputEventKey or not event.pressed or event.echo:return
 if event.keycode==KEY_ESCAPE:leave_room();get_viewport().set_input_as_handled()
 elif event.keycode==KEY_E:
  var result:=collect_remains();host.save_feedback(result.reason);get_viewport().set_input_as_handled()
