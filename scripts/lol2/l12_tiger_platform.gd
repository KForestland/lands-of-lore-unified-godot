extends Node3D
## Owner's Brady-side modern replacement. Prima's globe is untouched.
## Group824 has unknown opcode208, so it is NOT executed. Its nine published
## floor destinations are reused explicitly; region1899 and this switch/reward
## are modern, not a decoded native trigger or original axe placement.
const KEY:="l12_tiger_platform"
const RESTORE_ON:=["load"]
const SWITCH:=Vector3(3430,-218,-6580)
const PLATFORM:=1899
const TOP:=-150
const SPEED:=10
const FLOORS:={1901:-175,1828:-150,1897:-150,1905:-150,1907:-150,1902:-200,1898:-200,1900:-200,1906:-200,1899:TOP}
const ITEM:="act2:L12_CM:blizzard"
const Use=preload("res://scripts/lol2/owner_modern_use.gd")
const Grants=preload("res://scripts/lol2/item_grants.gd")
const Items=preload("res://scripts/lol2/item_definitions.gd")
var host:Node3D
var lever:Node3D
var handle:Node3D
var sprite:Sprite3D
var hint:Label
## Owner F10 2026-11-16T16-32-02 (r19o8, lead pick): the raised lake platforms were bare floor slabs over a hole in the
## lake (the map has no walls there), drawn as sky and void smears. Each platform is a solid ice column: walls along
## every edge of its floor, children of the moving deck, from its top down through its full rise (under the lake until
## it rises), in the deck's ice texture, with collision so nobody walks under it. The longplay (194-203, 226-231 min)
## never shows the platforms raised; this rise is the modern replacement above.
const LAKE_FLOOR:=-275.0
const OUTLINES:={
 1901:[Vector2(3707,-8708),Vector2(3735,-8747),Vector2(3774,-8718),Vector2(3745,-8681)],
 1828:[Vector2(3708,-8609),Vector2(3745,-8681),Vector2(3806,-8626),Vector2(3758,-8617)],
 1897:[Vector2(3774,-8718),Vector2(3830,-8783),Vector2(3840,-8732),Vector2(3847,-8685)],
 1905:[Vector2(3672,-8807),Vector2(3718,-8817),Vector2(3771,-8825),Vector2(3735,-8747)],
 1907:[Vector2(3641,-8690),Vector2(3631,-8748),Vector2(3707,-8708),Vector2(3649,-8649)],
 1902:[Vector2(3649,-8649),Vector2(3707,-8708),Vector2(3745,-8681),Vector2(3708,-8609)],
 1898:[Vector2(3745,-8681),Vector2(3774,-8718),Vector2(3847,-8685),Vector2(3806,-8626)],
 1900:[Vector2(3735,-8747),Vector2(3771,-8825),Vector2(3830,-8783),Vector2(3774,-8718)],
 1906:[Vector2(3631,-8748),Vector2(3672,-8807),Vector2(3735,-8747),Vector2(3707,-8708)],
 1899:[Vector2(3771,-8825),Vector2(3870,-9015),Vector2(3975,-8942),Vector2(3830,-8783)],
}
var columns_done:=false
static func initial()->Dictionary:return {"version":1,"activated":false,"taken":false}
static func validate(value:Variant,quests:Dictionary)->String:
 if not value is Dictionary or value.size()!=3 or value.get("version")!=1 or not value.get("activated") is bool or not value.get("taken") is bool:return "Invalid tiger-cave platform receipt."
 if value.taken and not value.activated:return "Tiger platform reward lacks switch receipt."
 if value.taken and ITEM not in quests.get("act2_items",{}).get("collected",[]):return "Tiger platform axe lacks pickup receipt."
 return ""
static func attach(map:Node3D)->Node:
 var node=load("res://scripts/lol2/l12_tiger_platform.gd").new();node.host=map;node.name="L12TigerPlatform";map.add_child(node);return node
func state()->Dictionary:return host.quest_state.get(KEY,initial())
func cube(parent:Node3D,size:Vector3,at:Vector3,color:Color):
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.position=at
 var material:=StandardMaterial3D.new();material.albedo_color=color;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material;parent.add_child(mesh)
func _ready():
 lever=Node3D.new();lever.position=SWITCH;add_child(lever)
 cube(lever,Vector3(22,12,22),Vector3(0,-26,0),Color(0.32,0.34,0.38))
 handle=Node3D.new();handle.position=Vector3(0,-20,0);lever.add_child(handle);cube(handle,Vector3(5,30,5),Vector3(0,15,0),Color(0.68,0.58,0.34));cube(handle,Vector3(18,6,6),Vector3(0,30,0),Color(0.4,0.22,0.1))
 sprite=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(Items.icon(18)));sprite.pixel_size=0.5;sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(sprite)
 hint=preload("res://scripts/lol2/interaction_hint_label.gd").attach(self,Vector2(24,455));restore()
 claim_decks.call_deferred()
## Owner F10 2026-11-16T16-30-04 (r19o8 freeze at this switch): the ten lake decks are cut from the static floor while the
## area loads, not on the frame E pulls the switch; the pull then only starts their motion. Unpulled saves only (a pulled
## save's decks come back with its saved floor motion).
func claim_decks():
 if state().activated or not is_instance_valid(host) or host.get("progression")==null:return
 for region:int in FLOORS:host.progression._claim_region_floor(region)
func columns()->void:
 if columns_done or host.get("progression")==null:return
 var built:=0
 for region:int in FLOORS:
  var deck:Node3D=host.progression.floor_decks.get(region)
  if deck==null:continue
  if deck.has_node("IceColumn"):built+=1;continue
  var bottom:float=LAKE_FLOOR-(float(FLOORS[region])-LAKE_FLOOR)
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var faces:=PackedVector3Array()
  var outline:Array=OUTLINES[region]
  for i in outline.size():
   var a:Vector2=outline[i];var b:Vector2=outline[(i+1)%outline.size()];var run:=a.distance_to(b)
   var quad:=[Vector3(a.x,LAKE_FLOOR,a.y),Vector3(b.x,LAKE_FLOOR,b.y),Vector3(b.x,bottom,b.y),Vector3(a.x,bottom,a.y)]
   var uvs:=[Vector2(0,0),Vector2(run/64.0,0),Vector2(run/64.0,(LAKE_FLOOR-bottom)/64.0),Vector2(0,(LAKE_FLOOR-bottom)/64.0)]
   for k in [0,1,2,0,2,3]:tool.set_uv(uvs[k]);tool.add_vertex(quad[k]);faces.append(quad[k])
  tool.generate_normals()
  var body:=AnimatableBody3D.new();body.name="IceColumn";body.collision_layer=1;body.collision_mask=0;body.sync_to_physics=false
  var mesh:=MeshInstance3D.new();mesh.mesh=tool.commit()
  for child in deck.get_children():
   if child is MeshInstance3D and child.material_override!=null:mesh.material_override=child.material_override;break
  body.add_child(mesh)
  var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces)
  var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
  deck.add_child(body);built+=1
 columns_done=built==FLOORS.size()
func height()->float:return float(host.progression.regions[PLATFORM][1])
func ready_reward()->bool:return state().activated and not state().taken and absf(height()-TOP)<0.1
func restore():
 if not is_instance_valid(sprite):return
 handle.rotation.z=-0.8 if state().activated else 0.3
 sprite.position=Vector3(3890,height()+16,-8900);sprite.visible=ready_reward()
func activate()->bool:
 if state().activated or not Use.reaches(host,SWITCH):return false
 host.quest_state[KEY]={"version":1,"activated":true,"taken":false}
 for region:int in FLOORS:
  var ref:="0x22d0c:%d"%region
  host.progression.native.set_field(ref,host.progression.NativeHost.FIELD_FLOOR_TARGET,int(FLOORS[region]))
  host.progression.native.set_field(ref,host.progression.NativeHost.FIELD_FLOOR_RATE,SPEED)
  host.progression._start_floor(region,int(FLOORS[region]),SPEED)
 restore();host.save_feedback("The lake platforms rise.");return true
func take()->bool:
 if not ready_reward() or not Use.reaches(host,sprite.global_position):return false
 var result:=Grants.grant(host,ITEM,{"cap":true,"full_text":"Inventory full.","duplicate":"skip","history":"act2_once","sync":true,"hud":true})
 if not result.ok:host.save_feedback(result.reason);return true
 var next:=state().duplicate(true);next.taken=true;host.quest_state[KEY]=next;restore();host.save_feedback("You take Blizzard.");return true
func _process(_delta:float):
 restore();columns()
 hint.text="E — Raise lake platform" if not state().activated and Use.reaches(host,SWITCH) else "E — Take Blizzard" if ready_reward() and Use.reaches(host,sprite.global_position) else ""
func _unhandled_key_input(event:InputEvent):
 if Use.pressed(event) and (activate() or take()):get_viewport().set_input_as_handled()
