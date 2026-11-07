extends Node3D
## Original DSLAVE idle/background; modern Spire gate and jump entry.
const Release=preload("res://scripts/lol2/l13_dawn_release.gd")
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY="l13_dawn_prison"
const ROOT="res://assets/lol2/generated/l13_dawn/"
const PLATE=Vector3(-6251,-1045,-3061)
var pending:Dictionary={}
var release_media:Dictionary={}
var choice:OptionButton
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
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("visited") is bool or not s.get("released") is bool:return "Invalid Dawn prison state."
 if s.released and not Release.completed(quests.get(Release.KEY,{})):return "Dawn release precedes Dreamstone receipt."
 if s.visited:
  var lit:Array=quests.get("l13_spires",{}).get("lit",[])
  if "170" not in lit or "171" not in lit:return "Dawn visit precedes spires."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l13_dawn_prison.gd").new();n.host=map;n.name="L13DawnPrison";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 if not FileAccess.file_exists(ROOT+"dawn.json"):return
 media=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"dawn.json"));media.patches={"999":media.idle}
 if FileAccess.file_exists(ROOT+"release.json"):release_media=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"release.json"))
 room=CanvasLayer.new();room.layer=90;add_child(room)
 var black:=ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);room.add_child(black)
 panel=Control.new();panel.size=Vector2(640,400);room.add_child(panel)
 var background:=TextureRect.new();background.size=Vector2(640,400);background.texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+"background_001.png"));panel.add_child(background)
 patch=TextureRect.new();patch.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(patch)
 button=Button.new();button.position=Vector2(460,75);button.size=Vector2(145,30);button.text="Examine recess";button.pressed.connect(use_switch);panel.add_child(button)
 var help:=Label.new();help.position=Vector2(110,370);help.text="E — Examine recess   Enter — Skip speech   Esc — Leave";panel.add_child(help)
 choice=OptionButton.new();choice.position=Vector2(420,315);choice.size=Vector2(210,30);panel.add_child(choice)
 voice=AudioStreamPlayer.new();add_child(voice);room.visible=false
func all_ruloi_dead()->bool:
 for i in range(21,40):
  if float(host.act2_creatures.state.actors.get(str(i),{}).get("health",1))>0:return false
 return true
func can_enter()->bool:
 if not host.get_node("L13Spires").dawn_ready():return false
 if entered or entry_latched or media.is_empty() or host.player_form!=0 or not host.starting_magic.world_active():return false
 var p:Vector3=host.player.global_position
 return Vector2(p.x-PLATE.x,p.z-PLATE.z).length()<45 and p.y-32>PLATE.y+10 and p.y-32<PLATE.y+90 and not host.player.is_on_floor()
func enter()->bool:
 if not can_enter():return false
 var s:=state().duplicate(true);s.visited=true;host.quest_state[KEY]=s
 choice.clear();choice.add_item("Examine recess");choice.set_item_metadata(0,"")
 for item in host.carried_collected:
  choice.add_item(str(Items.row(item).get("label",item)));choice.set_item_metadata(choice.item_count-1,item)
 entered=true;entry_latched=true;room.visible=true;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;play("999");return true
func play(next:String):
 cue=next;elapsed=0;atlas_path="";voice.stop();patch.visible=not state().released
 var r:Dictionary=release_media.cues[cue] if cue!="999" else media.patches[cue]
 if not str(r.audio).is_empty():voice.stream=AudioStreamWAV.load_from_file(str(r.audio));voice.play()
 button.disabled=cue!="999" or state().released;choice.disabled=button.disabled
func use_switch()->bool:
 if not entered or cue!="999" or state().released:return false
 var item:String=str(choice.get_item_metadata(choice.selected))
 if item.is_empty():button.text="A stone-shaped recess";return true
 var result:=offer(item);button.text=str(result.get("reason","The seal opens."));return result.ok
func offer(item:String)->Dictionary:
 if not entered or cue!="999" or host.player_form!=0 or release_media.is_empty():return Release.Kit.refuse("Approach Dawn's prison recess.")
 var result:=Release.offer(host.quest_state.get(Release.KEY,Release.initial()),host.carried_collected,item)
 if not result.ok:return result
 pending={"item":item};play("500");return {"ok":true}
func finish():
 if cue=="500":
  var relationship:int=int(host.quest_state.get("monastery",{}).get("globals",{}).get("GV_DAWN_RELATIONSHIP",0))
  play("600" if relationship in [1,2] else "951");return
 if cue=="999":return
 var result:=Release.offer(host.quest_state.get(Release.KEY,Release.initial()),host.carried_collected,str(pending.get("item","")))
 if not result.ok:pending={};play("999");button.text=result.reason;return
 var s:=state().duplicate(true);s.released=true;host.quest_state[KEY]=s;host.quest_state[Release.KEY]=result.state
 host.carried_collected=result.inventory;host.quest_state.act2_items.collected.append(Release.REWARD);Items.sync(host)
 pending={};leave();host.save_feedback("Dawn is free. She gives you the Bestial Disk. You keep the Dreamstone.")
func leave():
 if not entered:return
 pending={};entered=false;room.visible=false;voice.stop();get_tree().paused=false
 if DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _physics_process(_delta):
 if entered:return
 if host.player.is_on_floor():entry_latched=false
 enter()
func _process(delta):
 if not entered:return
 elapsed+=delta
 var r:Dictionary=release_media.cues[cue] if cue!="999" else media.patches[cue]
 if cue!="999" and elapsed>=float(r.duration):finish();return
 if cue=="500":return
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
