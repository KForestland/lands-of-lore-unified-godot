extends Node3D
## Book-led blue bow on original Melt man89; native item36 is separately pinned as Shard31.
const KEY="l12_frozen_bow"
const ITEM="act2:L12_CM:blue_bow"
const POINT=Vector3(3381,-1046,-14629)
const PICKUP=Vector3(3356,-1090,-14610)
const WINDOW=3.0
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
var host:Node3D
var ice:Node3D
var sprite:Sprite3D
var hint:Label
class Receiver:
 extends RefCounted
 var owner:Node
 func _init(n:Node):owner=n
 func receive_spark_level(level:int)->bool:return owner.spark(level)
static func initial()->Dictionary:return {"version":1,"remaining":0.0,"taken":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("taken") is bool:return "Invalid frozen bow."
 var r=s.get("remaining")
 if not (r is int or r is float) or not is_finite(float(r)) or r<0 or r>WINDOW:return "Invalid frozen-bow timer."
 if s.taken and (r!=0 or ITEM not in quests.get("act2_items",{}).get("collected",[])):return "Frozen bow lacks pickup receipt."
 return ""
static func owns(f:Dictionary)->bool:return f.get("placement_kind")=="static_assembly" and int(f.get("source_index",-1))==89
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l12_frozen_bow.gd").new();n.host=map;n.name="L12FrozenBow";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func active()->bool:return host.player_form==0 and host.starting_magic.world_active()
func _ready():
 ice=Node3D.new();ice.name="OriginalMeltMan89";add_child(ice)
 var faces:Array=[]
 for f in JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file)).faces:
  if owns(f):faces.append(f)
 host.get_node("L12Glacier").build(ice,faces);ice.get_node("Collision").set_meta("spark_receiver",Receiver.new(self))
 sprite=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(Items.row(ITEM).icon));sprite.pixel_size=0.5;sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(sprite)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func restore():
 if not is_instance_valid(ice):return
 var frozen:bool=not state().taken and state().remaining<=0
 ice.visible=frozen;ice.get_node("Collision").collision_layer=1 if frozen else 0
 if host.preview_assemblies.solid_bodies.has(89):host.preview_assemblies.solid_bodies[89].collision_layer=0
 sprite.visible=state().remaining>0 and not state().taken;sprite.position=PICKUP-Vector3.UP*(1.0-float(state().remaining)/WINDOW)*70
func spark(level:int)->bool:
 if not active() or level not in [1,3] or state().taken or state().remaining>0:return false
 var s:=state().duplicate(true);s.remaining=WINDOW;host.quest_state[KEY]=s;restore();host.save_feedback("Take the bow before it sinks.");return true
func reachable()->bool:
 var d:Vector3=sprite.global_position-host.camera.global_position
 return d.length()<155 and d.length()>0.01 and (-host.camera.global_basis.z).dot(d.normalized())>0.85
func take(capacity:int=64)->Dictionary:
 if not active() or not reachable() or state().remaining<=0 or state().taken:return Kit.refuse("The bow is not within reach.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Inventory full.")
 var s:=state().duplicate(true);s.taken=true;s.remaining=0.0;host.quest_state[KEY]=s
 var packet:Dictionary=host.quest_state.get("act2_items",Items.initial()).duplicate(true);packet.collected.append(ITEM);host.quest_state.act2_items=packet;host.carried_collected.append(ITEM);Items.sync(host);restore()
 return {"ok":true,"reason":"You catch the blue bow."}
func _physics_process(delta:float):
 if host.starting_magic.world_active() and state().remaining>0:
  var s:=state().duplicate(true);s.remaining=maxf(0,float(s.remaining)-delta);host.quest_state[KEY]=s;restore()
func _process(_delta):hint.text="E — Catch the blue bow" if active() and reachable() and state().remaining>0 else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and active() and reachable() and state().remaining>0:
  host.save_feedback(take().reason);get_viewport().set_input_as_handled()
