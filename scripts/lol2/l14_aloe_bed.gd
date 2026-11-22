extends Node3D
## Owner-approved modern one-time harvest. Original prop82 timer/regrowth
## matcher remains UNKNOWN; this does not run its source groups.
const KEY:="l14_aloe_bed"
const RESTORE_ON:=["load"]
const POINT:=Vector3(607,24,-4139)
const Use=preload("res://scripts/lol2/owner_modern_use.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
const Aloe=preload("res://scripts/lol2/jungle_harvest_items.gd")
var host:Node3D
var hint:Label
var sprite:Sprite3D
static func initial()->Dictionary:return {"version":1,"item":""}
static func validate(value:Variant)->String:
 if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("item") is String:return "Invalid Temple plant-bed receipt."
 if not value.item.is_empty() and Aloe.kind(value.item)!="aloe":return "Invalid Temple plant-bed aloe."
 return ""
static func attach(map:Node3D)->Node:
 var node=load("res://scripts/lol2/l14_aloe_bed.gd").new();node.host=map;node.name="L14AloeBed";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 sprite=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(Aloe.ROOT+"aloe.png"));sprite.pixel_size=0.7;sprite.position=POINT-Vector3.UP*10;sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(sprite)
 hint=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,455));restore()
func restore():
 if is_instance_valid(sprite):sprite.visible=state().item.is_empty() # One existing Aloe icon; no invented growth cycle.
func available()->bool:return state().item.is_empty() and Use.reaches(host,POINT)
func take()->bool:
 if not available():return false
 var item:String=Aloe.next_free("aloe",Grants.pack(host).duplicate())
 if item.is_empty():host.save_feedback("You cannot carry more.");return true
 var result:=Grants.grant(host,item,{"cap":true,"full_text":"Inventory full.","sync":true,"hud":true})
 if not result.ok:host.save_feedback(result.reason);return true
 # Existing Jungle renewable pool convention; a consumed pool id can be
 # harvested again. This bed grants only once and adds no regrowth timer.
 host.item_effects.state().spent.erase(item)
 host.quest_state[KEY]={"version":1,"item":item};restore()
 host.save_feedback("Aloe added to inventory.")
 return true
func _process(_delta:float):hint.text="E — Take aloe" if available() else ""
func _unhandled_key_input(event:InputEvent):
 if Use.pressed(event) and take():get_viewport().set_input_as_handled()
