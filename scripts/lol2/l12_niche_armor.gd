extends Node3D
const KEY="l12_niche_armor"
const ITEM="act2:L12_CM:item5"
const POINT=Vector3(-55,-1130,-14164)
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
var host:Node3D
var sprite:Sprite3D
var hint:Label
class Receiver:
 extends RefCounted
 var owner:Node
 func _init(n:Node):owner=n
 func receive_spark_level(level:int)->bool:return owner.spark(level)
static func initial()->Dictionary:return {"version":1,"revealed":false,"taken":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not s.get("revealed") is bool or not s.get("taken") is bool:return "Invalid niche armor."
 if s.taken and (not s.revealed or ITEM not in quests.get("act2_items",{}).get("collected",[])):return "Niche armor lacks earned receipt."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l12_niche_armor.gd").new();n.host=map;n.name="L12NicheArmor";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func active()->bool:return host.player_form==0 and host.starting_magic.world_active()
func _ready():
 var body:=StaticBody3D.new();body.position=POINT;body.collision_mask=0;body.set_meta("spark_receiver",Receiver.new(self));add_child(body)
 var box:=BoxShape3D.new();box.size=Vector3(22,48,22);var shape:=CollisionShape3D.new();shape.shape=box;body.add_child(shape)
 sprite=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(Items.row(ITEM).icon));sprite.pixel_size=0.5;sprite.position=Vector3(-59,-1160,-14165);sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(sprite)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func restore():
 if is_instance_valid(sprite):sprite.visible=state().revealed and not state().taken
func spark(level:int)->bool:
 if not active() or level not in [1,3] or state().revealed:return false
 var s:=state().duplicate(true);s.revealed=true;host.quest_state[KEY]=s;restore();host.save_feedback("Obsidian chain mail appears beside the fixture.");return true
func reachable()->bool:
 var d:Vector3=POINT-host.camera.global_position
 return d.length()<155 and d.length()>0.01 and (-host.camera.global_basis.z).dot(d.normalized())>0.85
func take(capacity:int=64)->Dictionary:
 if not active() or not reachable() or not state().revealed:return Kit.refuse("Spark the niche fixture first.")
 if state().taken or ITEM in host.carried_collected:return Kit.refuse("The armor has already been taken.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Inventory full.")
 var s:=state().duplicate(true);s.taken=true;host.quest_state[KEY]=s
 var packet:Dictionary=host.quest_state.get("act2_items",Items.initial()).duplicate(true);packet.collected.append(ITEM);host.quest_state.act2_items=packet
 host.carried_collected.append(ITEM);Items.sync(host);host.set_equipped_armor(ITEM);restore()
 return {"ok":true,"reason":"You put on the obsidian chain mail."}
func _process(_delta):hint.text="E — Take and wear obsidian chain mail" if active() and reachable() and state().revealed and not state().taken else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and active() and reachable() and state().revealed:
  host.save_feedback(take().reason);get_viewport().set_input_as_handled()
