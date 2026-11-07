extends Node3D
## Prop297 hit groups6692/6720/6748 reveal original placed items6/5/4.
## Native AE2C8 filter replay: positive melee admitted, Spark1/1 refused.
const State = preload("res://scripts/lol2/museum_crystal_state.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const ROOT := "res://assets/lol2/generated/museum_crystal/"
const SOURCE := "res://scripts/lol2/museum_crystal_source.json"
var host: Node3D
var state := State.initial()
var source: Dictionary
var pickups: Array[Sprite3D] = []
var sounds: Array[AudioStreamPlayer3D] = []
var body: StaticBody3D
class HitBody extends StaticBody3D:
	func receive_spark() -> bool: return false
static func assets_ready() -> bool: return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT+"burnt.png")
func setup(owner: Node3D, saved: Variant=null) -> String:
	host=owner;name="MuseumCrystal"
	source=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var texture:=ImageTexture.create_from_image(Image.load_from_file(ROOT+"burnt.png"))
	for row in source.items:
		var sprite:=Sprite3D.new();sprite.texture=texture;sprite.pixel_size=0.5
		sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		var p:Array=row.position;sprite.position=Vector3(p[0],float(p[1])+texture.get_height()*0.25,p[2]);add_child(sprite);pickups.append(sprite)
		var sound:=AudioStreamPlayer3D.new();sound.stream=AudioStreamWAV.load_from_file(ROOT+str(int(row.sound))+".wav");sound.unit_size=64;sound.position=Vector3(-1305,50,-722);add_child(sound);sounds.append(sound)
	body=HitBody.new();body.collision_layer=2;body.collision_mask=0;body.position=Vector3(-1305,50.5,-722);body.set_meta("spark_receiver",body);add_child(body)
	var box:=BoxShape3D.new();box.size=Vector3(43,81,43);var shape:=CollisionShape3D.new();shape.shape=box;body.add_child(shape)
	return restore_checkpoint(saved)
func checkpoint() -> Dictionary: return state.duplicate(true)
func restore_checkpoint(saved: Variant) -> String:
	var error:=State.validate(saved,host.carried_collected)
	if not error.is_empty():return error
	state=State.canonical(saved)
	for sound in sounds:sound.stop()
	present();return ""
func present() -> void:
	for i in 3:pickups[i].visible=i<int(state.hits) and not state.taken[i]
func active() -> bool:
	return is_instance_valid(host.starting_magic) and host.starting_magic.world_active()
func strike() -> bool:
	if not active() or host.player_form==2:return false
	if host.player_form==0 and (host.equipped_item not in host.carried_collected or Catalog.slot(host.equipped_item)!="weapon"):return false
	var origin:Vector3=host.camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(origin,origin-host.camera.global_basis.z*96,3,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider!=body:return false
	if not State.hit(state,2,4,1):return false
	sounds[int(state.hits)-1].play();present();return true
func offered() -> int:
	if not active() or host.hand_item!="":return -1
	for i in 3:
		if pickups[i].visible and can_reach_pickup(pickups[i].global_position):return i
	return -1
func use() -> bool:
	var i:=offered()
	if i<0:return false
	if host.carried_collected.size()>=Catalog.MAX_CARRIED:host.save_feedback("You cannot carry more.");return true
	if State.IDS[i] in host.carried_collected:return false
	host.carried_collected.append(State.IDS[i]);state.taken[i]=true
	var effects:Dictionary=host.item_effects.state()
	if not effects.has("fire_crystals"):effects.fire_crystals={}
	effects.fire_crystals[State.IDS[i]]=0
	present();host.save_feedback("Burnt fire crystal added to inventory.");return true
func interaction_hint() -> String:return "E — Take burnt fire crystal" if offered()>=0 else ""
func _process(_delta: float) -> void:
	for sound in sounds:sound.stream_paused=not active()

func can_reach_pickup(target: Vector3) -> bool:
	var origin:Vector3=host.camera.global_position
	var offset:=target-origin
	if offset.length()<0.01 or offset.length()>96 or (-host.camera.global_basis.z).dot(offset.normalized())<0.97:return false
	# The exhibit's attack-only volume overlaps original item placements; it must not occlude its own pickups.
	var query:=PhysicsRayQueryParameters3D.create(origin,target,preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
	query.exclude=[host.player.get_rid(),body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
