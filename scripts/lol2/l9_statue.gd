extends Node3D
## Original region3185/group3774 -> prop2622/STAT room20. The source bowl hotspot owns Kit offering.
const State=preload("res://scripts/lol2/l9_statue_state.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const POLYGON:=[Vector2(2609.85,-5979.78),Vector2(2513.3,-5971.09),Vector2(2506.31,-6000.48),Vector2(2609.13,-6011.12)]
var host: Node3D
var room: CanvasLayer
var panel: Control
var picture: TextureRect
var frames: Array[Texture2D]=[]
var room_active:=false
var elapsed:=0.0
var hint: Label
var entry_latched:=false
static func attach(map: Node3D)->Node3D:
 var node=load("res://scripts/lol2/l9_statue.gd").new();node.host=map;node.name="L9Statue";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get("l9_statue",State.initial())
func active()->bool:return not get_tree().paused and not host.flying and host.player_form==0 and host.starting_magic.world_active()
func in_alcove()->bool:
 var p: Vector3=host.player.global_position
 return absf(p.y-32)<15 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),PackedVector2Array(POLYGON))
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 var root_path:="res://assets/lol2/generated/l9_statue/"
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path+"statue.json"))
 for f in data.frames:frames.append(ImageTexture.create_from_image(Image.load_from_file(root_path+f.file)))
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,450);canvas.add_child(hint)
 room=CanvasLayer.new();room.layer=80;add_child(room)
 var shade:=ColorRect.new();shade.color=Color.BLACK;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);room.add_child(shade)
 panel=Control.new();panel.size=Vector2(640,400);room.add_child(panel)
 picture=TextureRect.new();picture.size=Vector2(640,400);picture.texture=frames[0];panel.add_child(picture)
 var bowl:=Button.new();bowl.name="LeftBowl";bowl.position=Vector2(145,185);bowl.size=Vector2(130,144);bowl.flat=true;bowl.tooltip_text="Place the Emperor's remains in the bowl";bowl.pressed.connect(func():var result:=offer(State.REMAINS);host.save_feedback(result.reason));panel.add_child(bowl)
 var label:=Label.new();label.position=Vector2(100,370);label.text="E — Offer the Emperor's remains     Esc — Leave";panel.add_child(label)
 room.visible=false
func enter()->Dictionary:
 if not active() or not in_alcove():return State.Kit.refuse("Enter the courtyard alcove as Human.")
 var next:=state().duplicate(true);next.visited=true;host.quest_state.l9_statue=next
 if State.offered(next):return State.Kit.refuse("The remains have already been offered.")
 if State.REMAINS not in host.carried_collected:return {"ok":true,"reason":"Huh?","question":true}
 room_active=true;room.visible=true;elapsed=0;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 return {"ok":true,"reason":"A large bowl stands on the left.","question":false}
func offer(item: String)->Dictionary:
 if not room_active:return State.Kit.refuse("Enter the statue room first.")
 var result:=State.offer(state(),host.carried_collected,item)
 if not result.ok:return result
 host.quest_state.l9_statue=result.state;host.carried_collected=result.inventory;Items.sync(host);leave()
 return {"ok":true,"reason":"The remains settle in the bowl. The statue begins to stir."}
func leave():
 room_active=false;room.visible=false;get_tree().paused=false
 if DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _process(delta):
 hint.text=""
 if room_active:
  elapsed+=delta;picture.texture=frames[int(elapsed*15)%frames.size()]
  var viewport:=get_viewport().get_visible_rect().size;var factor:=minf(viewport.x/640.0,viewport.y/400.0)
  panel.scale=Vector2.ONE*factor;panel.position=(viewport-Vector2(640,400)*factor)/2
  return
 # HINTBOOK 3789-3791: entering the alcove starts the scene. L9 region 3185 kind 12 event 2 group 3774 opens stat_.
 if not (active() and in_alcove()):
  entry_latched=false
  return
 if get_tree().paused:return
 if not entry_latched and not State.offered(state()):
  if host.has_method("actor_input_locked") and host.actor_input_locked():return
  entry_latched=true
  var result:=enter()
  host.save_feedback(result.reason)
  if room_active:return
 if not State.offered(state()):hint.text="E — Examine the statue alcove"
func _input(event: InputEvent):
 if not room_active or event is not InputEventKey or not event.pressed or event.echo:return
 if event.keycode==KEY_ESCAPE:leave();get_viewport().set_input_as_handled()
 elif event.keycode==KEY_E:
  var result:=offer(State.REMAINS);host.save_feedback(result.reason);get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent):
 if event is not InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_E:return
 if not active() or not in_alcove() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or is_instance_valid(host.inventory):return
 if host.has_method("actor_input_locked") and host.actor_input_locked():return
 var result:=enter();host.save_feedback(result.reason);get_viewport().set_input_as_handled()
