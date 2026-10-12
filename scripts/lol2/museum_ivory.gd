extends Node3D
## Museum urn189/195 activate placed items17/18. Source, art, and native filter: museum_ivory_source.json.
## Uses existing melee/E/Spark controls. Original sounds and non-Spark spell hits remain unhosted.
## Both decoded selector images are identical; hide the spent urn as a clear modern break presentation.
const State = preload("res://scripts/lol2/museum_ivory_state.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const ROOT := "res://assets/lol2/generated/museum_ivory/"
const SOURCE := "res://scripts/lol2/museum_ivory_source.json"
class UrnBody extends StaticBody3D:
	var receiver: Node3D
	var index: int
	func receive_spark() -> void: receiver.receive_hit(index,8)
var host: Node3D
var source: Dictionary
var state := State.initial()
var urns: Array[Sprite3D] = []
var chips: Array[Sprite3D] = []
var bodies: Array[StaticBody3D] = []
var textures: Array[ImageTexture] = []
static func assets_ready() -> bool:
	for path in [SOURCE,ROOT+"urn_0.png",ROOT+"urn_1.png",ROOT+"ivory.png"]:
		if not FileAccess.file_exists(path): return false
	return true
func setup(owner: Node3D, saved: Variant = null) -> String:
	host=owner;name="MuseumIvory"
	source=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for i in 2: textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT+"urn_%d.png"%i)))
	for i in 2:
		var row: Dictionary=source.containers[i]
		var art: Dictionary=source.art[1]
		var p: Array=row.position
		var centre:=Vector3(p[0],float(p[1])+(float(art.top)+float(art.bottom))/2.0,p[2])
		var urn:=sprite(textures[1],centre,(float(art.right)-float(art.left))/textures[1].get_width())
		urns.append(urn)
		# Hit-only layer2: ray attacks see it; player movement remains governed by the map geometry.
		var body:=UrnBody.new();body.receiver=self;body.index=i;body.collision_layer=2;body.collision_mask=0
		body.set_meta("spark_receiver",body);body.position=centre;add_child(body)
		var shape:=BoxShape3D.new();shape.size=Vector3(32,29,32)
		var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);bodies.append(body)
		p=row.item_position
		chips.append(sprite(ImageTexture.create_from_image(Image.load_from_file(ROOT+"ivory.png")),Vector3(p[0],float(p[1])+5.25,p[2]),0.5))
	return restore_checkpoint(saved)
func sprite(texture: Texture2D, point: Vector3, scale: float) -> Sprite3D:
	var result:=Sprite3D.new();result.texture=texture;result.pixel_size=scale
	result.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;result.position=point;add_child(result)
	return result
func checkpoint() -> Dictionary: return state.duplicate(true)
func restore_checkpoint(value: Variant) -> String:
	var saved: Variant=State.initial() if value==null else value
	var error:=State.validate(saved,host.carried_collected)
	if not error.is_empty(): return error
	state={"version":1,"stages":[int(saved.stages[0]),int(saved.stages[1])]};present();return ""
func present() -> void:
	for i in 2:
		urns[i].visible=state.stages[i]==0
		chips[i].visible=state.stages[i]==1
		bodies[i].collision_layer=2 if state.stages[i]==0 else 0
func active() -> bool:
	return is_instance_valid(host.starting_magic) and host.starting_magic.world_active()
func receive_hit(index: int, damage: int) -> bool:
	if not active() or not State.hit(state,index,damage): return false
	present();host.save_feedback("The urn breaks, revealing an ivory chip.");return true
func strike() -> bool:
	if not active(): return false
	if host.player_form==0 and (not host.equipped_item in host.carried_collected or Catalog.slot(host.equipped_item)!="weapon"): return false
	if host.player_form==2: return false
	var origin: Vector3=host.camera.global_position
	var ray:=PhysicsRayQueryParameters3D.create(origin,origin-host.camera.global_basis.z*96,3,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider in bodies: return false
	return receive_hit(bodies.find(hit.collider),1)
func offered() -> int:
	if not active() or host.hand_item!="": return -1
	for i in 2:
		if state.stages[i]==1 and host.can_reach_item(chips[i].global_position): return i
	return -1
func interaction_hint() -> String: return "E — Take Ivory Chip" if offered()>=0 else ""
func use() -> bool:
	var i:=offered()
	if i<0: return false
	if not State.take(state,i,host.carried_collected,Catalog.MAX_CARRIED):
		host.save_feedback("You cannot carry more.");return true
	present();host.save_feedback("Ivory Chip added to inventory.");return true
