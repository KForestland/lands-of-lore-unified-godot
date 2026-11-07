extends Node3D
## Source prop216 movie and item25. Sprite keying, collision box, E aim and RNG stream are modern adapters.
const State=preload("res://scripts/lol2/museum_dragon_heart_state.gd")
const Catalog=preload("res://scripts/lol2/item_catalog.gd")
const ROOT="res://assets/lol2/generated/museum_dragon_heart/"
class HeartBody extends StaticBody3D:
	var receiver: Node3D
	func receive_spark() -> void:receiver.receive_spark()
var host: Node3D
var state: Dictionary=State.initial()
var display: MeshInstance3D
var gem: Sprite3D
var body: HeartBody
var material: StandardMaterial3D
var idle: ImageTexture
var movie: ImageTexture
var spent: ImageTexture
var audio: AudioStreamPlayer3D
var regions: Array=[]
var last_region := -1
func setup(owner: Node3D,saved: Variant=null) -> String:
	host=owner;name="MuseumDragonHeart"
	for instance in host.museum_props.instances:
		if int(instance.get_meta("source_record",-1))==215:instance.hide()
	regions=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/museum_dragon_heart_regions.json"))
	idle=ImageTexture.create_from_image(Image.load_from_file(ROOT+"descriptor_121.png"))
	movie=ImageTexture.create_from_image(Image.load_from_file(ROOT+"atlas.png"))
	spent=ImageTexture.create_from_image(Image.load_from_file(ROOT+"descriptor_836.png"))
	material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	display=MeshInstance3D.new();display.mesh=QuadMesh.new();display.material_override=material;add_child(display)
	body=HeartBody.new();body.receiver=self;body.position=Vector3(-1141,30,-2207)
	body.collision_layer=2;body.collision_mask=0;body.set_meta("spark_receiver",body)
	var shape:=BoxShape3D.new();shape.size=Vector3(100,60,8)
	var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)
	gem=Sprite3D.new();gem.texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+"gem.png"))
	gem.pixel_size=0.5;gem.position=Vector3(-1154,8,-2185)
	gem.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;gem.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gem.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;add_child(gem)
	audio=AudioStreamPlayer3D.new();audio.stream=AudioStreamWAV.load_from_file(ROOT+"voice.wav")
	audio.position=body.position;audio.unit_size=180;add_child(audio)
	return restore(saved)
func checkpoint() -> Dictionary:return state.duplicate(true)
func restore(value: Variant) -> String:
	var error:=State.validate(value,host.carried_collected)
	if not error.is_empty():return error
	state=State.initial() if value==null else value.duplicate(true)
	last_region=-1;audio.stop();present();return ""
func active() -> bool:
	return is_instance_valid(host.starting_magic) and host.starting_magic.world_active() and not get_tree().paused and not host.flying
func receive_spark() -> bool:
	if not active() or state.phase!="idle":return false
	var saved: Dictionary=host.starting_magic.magic_state()
	var maxima: Array=[];maxima.resize(31);maxima.fill(159)
	var random:=preload("res://scripts/lol2/hive_rune_transaction.gd").draws(int(saved.get("spark_reward_seed",324508639)),maxima)
	var reward:=preload("res://scripts/lol2/hive_magic_reward.gd").award_checkpoint(saved,50,random.values)
	if reward.has("error"):push_error(reward.error);return false
	reward.checkpoint.spark_reward_seed=int(random.seeds[reward.draws_used])
	if not State.spark(state):return false
	host.starting_magic.commit(reward.checkpoint);present();return true
func region_at(point: Vector3) -> int:
	for row in regions:
		if point.y<row.floor-1 or point.y>row.ceiling+1:continue
		var polygon:=PackedVector2Array()
		for p in row.polygon:polygon.append(Vector2(p[0],p[1]))
		if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon):return int(row.region)
	return -1
func _physics_process(delta: float) -> void:
	var running:=active()
	audio.stream_paused=not running
	if not running:return
	State.advance(state,delta)
	var region:=region_at(host.player.position)
	if region!=last_region:State.region_enter(state,region);last_region=region
	present()
	if state.phase=="playing" and not audio.playing:audio.play(float(state.elapsed))
	elif state.phase!="playing" and audio.playing:audio.stop()
func present() -> void:
	var movie_visible: bool=state.phase in ["playing","revealed"]
	# Completion property16 stops owner sounds; it does not unlink this prop.
	# The loaded movie remains until the explicit unload/unlink region commands.
	display.visible=true
	display.position=Vector3(-1142,0,-2208) if state.phase=="departed" else Vector3(-1141,0,-2207)
	var quad: QuadMesh=display.mesh
	quad.size=Vector2(100,60) if state.phase=="idle" else Vector2(120,75)
	quad.center_offset=Vector3(0,quad.size.y/2,0)
	material.albedo_texture=movie if movie_visible else spent if state.phase=="departed" else idle
	var frame:=mini(19,int(float(state.elapsed)*15))
	material.uv1_scale=Vector3(0.2,0.25,1) if movie_visible else Vector3.ONE
	material.uv1_offset=Vector3(float(frame%5)/5,float(frame/5)/4,0) if movie_visible else Vector3.ZERO
	body.collision_layer=2 if state.phase=="idle" else 0
	gem.visible=state.phase in ["revealed","departed"] and not state.taken
func reachable() -> bool:
	if not active() or not gem.visible or host.hand_item!="":return false
	var delta: Vector3=gem.global_position-host.camera.global_position
	if delta.length()<0.01 or delta.length()>96 or (-host.camera.global_basis.z).dot(delta.normalized())<0.97:return false
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,gem.global_position,1,[host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func interaction_hint() -> String:return "E — Take Dragon Gem" if reachable() else ""
func use() -> bool:
	if not reachable():return false
	if host.carried_collected.size()>=Catalog.MAX_CARRIED:host.save_feedback("You cannot carry more.");return true
	host.carried_collected.append(State.ITEM);state.taken=true;present();host.save_feedback("Dragon Gem added to inventory.");return true
