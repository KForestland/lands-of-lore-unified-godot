extends Node3D
## Original SLAVES media/local consumer; modern jump entry, saved release and live actor gate.
const KEY="l13_prison"
const ROOT="res://assets/lol2/generated/l13_prison/"
const PLATE=Vector3(-4090,-1045,-2833)
var host:Node3D
var media:Dictionary
var room:CanvasLayer
var panel:Control
var patch:TextureRect
var voice:AudioStreamPlayer
var entered:=false
var entry_latched:=false
var cue:="999"
var elapsed:=0.0
var atlas_path:=""
var atlas:Texture2D
var button:Button
static func initial()->Dictionary:return {"version":1,"visited":false,"released":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("visited") is bool or not s.get("released") is bool:return "Invalid citadel prison state."
 if s.released:
  if not s.visited:return "Prison release precedes visit."
  for i in range(21,40):
   if float(quests.get("act2_creatures_L13_RC",{}).get("actors",{}).get(str(i),{}).get("health",1))>0:return "Prison release precedes Ruloi defeat."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_prison.gd").new();n.host=map;n.name="L13Prison";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 if not FileAccess.file_exists(ROOT+"prison.json"):return
 media=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"prison.json"))
 room=CanvasLayer.new();room.layer=90;add_child(room)
 var black:=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);room.add_child(black)
 panel=Control.new();panel.size=Vector2(640,400);room.add_child(panel)
 var background:=TextureRect.new();background.size=Vector2(640,400);background.texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+"background_001.png"));panel.add_child(background)
 patch=TextureRect.new();patch.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(patch)
 button=Button.new();button.position=Vector2(100,30);button.size=Vector2(145,30);button.text="Use upper-left switch";button.pressed.connect(use_switch);panel.add_child(button)
 var help:=Label.new();help.position=Vector2(110,370);help.text="E — Use switch   Enter — Skip speech   Esc — Leave";panel.add_child(help)
 voice=AudioStreamPlayer.new();add_child(voice);room.visible=false
func all_ruloi_dead()->bool:
 for i in range(21,40):
  if float(host.act2_creatures.state.actors.get(str(i),{}).get("health",1))>0:return false
 return true
func can_enter()->bool:
 if entered or entry_latched or media.is_empty() or host.player_form!=0 or not host.starting_magic.world_active():return false
 var p:Vector3=host.player.global_position
 return Vector2(p.x-PLATE.x,p.z-PLATE.z).length()<45 and p.y-32>PLATE.y+10 and p.y-32<PLATE.y+90 and not host.player.is_on_floor()
func enter()->bool:
 if not can_enter():return false
 var s:=state().duplicate(true);s.visited=true;host.quest_state[KEY]=s
 entered=true;entry_latched=true;room.visible=true;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;play("999");return true
func play(next:String):
 cue=next;elapsed=0;atlas_path="";voice.stop();patch.visible=not state().released
 var r:Dictionary=media.release if cue=="release" else media.patches[cue]
 if not str(r.audio).is_empty():voice.stream=AudioStreamWAV.load_from_file(str(r.audio));voice.play()
 button.disabled=cue!="999" or state().released
func use_switch()->bool:
 if not entered or state().released or cue!="999":return false
 play("release" if all_ruloi_dead() else "11");return all_ruloi_dead()
func finish():
 if cue=="release":
  if not all_ruloi_dead():leave();return
  var s:=state().duplicate(true);s.released=true;host.quest_state[KEY]=s;leave()
 elif cue!="999":play("999")
func leave():
 if not entered:return
 entered=false;room.visible=false;voice.stop();get_tree().paused=false
 if DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _physics_process(_delta):
 if entered:return
 if host.player.is_on_floor():entry_latched=false
 enter()
func _process(delta):
 if not entered:return
 elapsed+=delta
 var r:Dictionary=media.release if cue=="release" else media.patches[cue]
 if cue!="999" and elapsed>=float(r.duration):finish();return
 var index:int=int(elapsed*15)%int(r.frames);var path:String=r.atlases[index/16]
 if path!=atlas_path:atlas=ImageTexture.create_from_image(Image.load_from_file(path));atlas_path=path
 var frame:=AtlasTexture.new();frame.atlas=atlas;frame.region=Rect2((index%4)*r.width,((index%16)/4)*r.height,r.width,r.height);patch.texture=frame;patch.position=Vector2(r.x,r.y);patch.size=Vector2(r.width,r.height)
 var viewport:=get_viewport().get_visible_rect().size;var scale_by:=minf(viewport.x/640,viewport.y/400);panel.scale=Vector2.ONE*scale_by;panel.position=(viewport-panel.size*scale_by)/2
func _input(event:InputEvent):
 if not entered or not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode==KEY_ESCAPE:leave()
 elif event.keycode==KEY_ENTER:finish()
 elif event.keycode==KEY_E:use_switch()
 else:return
 get_viewport().set_input_as_handled()
