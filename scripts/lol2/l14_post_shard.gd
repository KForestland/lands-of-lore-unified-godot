extends Node3D
const KEY="l14_post_shard"
const ITEM="act2:L14_HT:post_shard"
const POINT=Vector3(3043,30,-5684)
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
const Kit=preload("res://scripts/lol2/mechanism_transaction.gd")
var host:Node3D
var sprite:Sprite3D
var hint:Label
static func initial()->Dictionary:return {"version":1,"taken":false}
static func validate(s:Variant,quests:Dictionary)->String:
 if not s is Dictionary or s.size()!=2 or s.get("version")!=1 or not s.get("taken") is bool:return "Invalid post shard state."
 if s.taken!=(ITEM in quests.get("act2_items",{}).get("collected",[])):return "Post shard receipt mismatch."
 return ""
static func attach(map:Node3D)->Node:
 var n=load("res://scripts/lol2/l14_post_shard.gd").new();n.host=map;n.name="L14PostShard";map.add_child(n);return n
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func _ready():
 sprite=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(Items.row(ITEM).icon));sprite.pixel_size=0.5;sprite.position=POINT;sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(sprite)
 var canvas:=CanvasLayer.new();canvas.layer=34;add_child(canvas);hint=Label.new();hint.position=Vector2(24,455);canvas.add_child(hint);restore()
func reachable()->bool:
 if host.player_form!=0 or host.flying or not host.starting_magic.world_active():return false
 var d:Vector3=POINT-host.camera.global_position
 if d.length()<0.01 or d.length()>125 or (-host.camera.global_basis.z).dot(d.normalized())<0.9:return false
 var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,POINT,1,[host.player.get_rid()])
 # The original post itself may be the last ray hit; reach/facing bind this pickup to it.
 var hit:Dictionary=host.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or hit.position.distance_to(POINT)<20
func take(capacity:int=64)->Dictionary:
 if not reachable():return Kit.refuse("Approach the crystal in the post.")
 if state().taken:return Kit.refuse("The crystal has already been taken.")
 if host.carried_collected.size()>=capacity:return Kit.refuse("Inventory full.")
 var packet:Dictionary=host.quest_state.get("act2_items",Items.initial()).duplicate(true);packet.collected.append(ITEM)
 host.quest_state[KEY]={"version":1,"taken":true};host.quest_state.act2_items=packet;host.carried_collected.append(ITEM);Items.sync(host);restore()
 return {"ok":true,"reason":"You take the green crystal shard from the post."}
func restore():
 if is_instance_valid(sprite):sprite.visible=not state().taken
func _process(_delta):
 restore();hint.text="E — Take green crystal shard" if reachable() and not state().taken else ""
func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and reachable() and not state().taken:
  host.save_feedback(take().reason);get_viewport().set_input_as_handled()
