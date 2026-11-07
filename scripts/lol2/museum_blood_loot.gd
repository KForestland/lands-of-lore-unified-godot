extends Node3D
## Actor20 arrival group12578 owns two separate Drag Blood items, property4 each.
## Modern five-active-second corpse retirement and aimed E pickup.
const ITEMS := ["museum:skeleton20:Dragon_Blood_1","museum:skeleton20:Dragon_Blood_2","museum:item1:Dragon_Blood","museum:item2:Dragon_Blood","museum:item3:Dragon_Blood"]
const ICON := "res://assets/lol2/generated/museum_blood_loot/icon.png"
const DELAY := 5.0
var host: Node3D
var state := {"elapsed":0.0,"taken":[false,false,false,false,false]}
var sprites: Array[Sprite3D]=[]
var placed: Array=[]
static func eligible(population: Dictionary) -> bool:
	var actor: Dictionary=population.get("actors",{}).get("20",{})
	return actor.get("present",false) and actor.get("health",1)==0
static func validate(saved: Variant,population: Dictionary,carried: Array,spent: Array) -> String:
	var packet: Variant={"elapsed":0.0,"taken":[false,false,false,false,false]} if saved==null else saved
	if not packet is Dictionary or packet.size()!=2 or not packet.get("taken") is Array or packet.taken.size()!=ITEMS.size():return "Invalid skeleton20 loot."
	var elapsed=packet.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>DELAY:return "Invalid skeleton20 loot clock."
	for i in ITEMS.size():
		if not packet.taken[i] is bool:return "Invalid skeleton20 loot receipt."
		if i<2 and packet.taken[i] and (elapsed!=DELAY or not eligible(population)):return "Skeleton20 loot lacks death."
		if packet.taken[i] != (ITEMS[i] in carried or ITEMS[i] in spent):return "Skeleton20 loot and inventory disagree."
	if elapsed>0 and not eligible(population):return "Skeleton20 loot lacks dead owner."
	return ""
func setup(owner: Node3D,saved: Variant=null) -> void:
	host=owner
	placed=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/museum_blood_source.json")).placed
	var texture:=ImageTexture.create_from_image(Image.load_from_file(ICON))
	for i in ITEMS.size():
		var sprite:=Sprite3D.new();sprite.texture=texture;sprite.pixel_size=0.35
		sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(sprite);sprites.append(sprite)
	restore(saved)
func checkpoint() -> Variant:
	return state.duplicate(true) if float(state.elapsed)>0 or state.taken.any(func(t):return t) else null
func restore(saved: Variant) -> void:
	state={"elapsed":0.0,"taken":[false,false,false,false,false]} if saved==null else saved.duplicate(true)
	present()
func active() -> bool:
	return is_instance_valid(host.starting_magic) and host.starting_magic.world_active() and not host.flying and not get_tree().paused
func advance(delta: float) -> void:
	if active() and is_finite(delta) and delta>0 and eligible(host.skeleton_population.state):state.elapsed=minf(DELAY,float(state.elapsed)+delta)
	present()
func present() -> void:
	if sprites.is_empty() or not is_instance_valid(host.skeleton_population):return
	var population=host.skeleton_population
	var retired:=eligible(population.state) and float(state.elapsed)>=DELAY
	if eligible(population.state):population.meshes["20"].visible=not retired
	for i in ITEMS.size():
		sprites[i].visible=(retired if i<2 else true) and not state.taken[i]
		if i<2:sprites[i].global_position=population.bodies["20"].global_position+Vector3(-9 if i==0 else 9,10,0)
		else:
			var p: Array=placed[i-2].position
			sprites[i].global_position=Vector3(p[0],p[1]+10,p[2])+population.origin()
func aimed() -> int:
	if not active():return -1
	var best:=-1;var best_dot:=0.97
	for i in ITEMS.size():
		if not sprites[i].visible:continue
		var delta: Vector3=sprites[i].global_position-host.camera.global_position
		if delta.length()<0.01 or delta.length()>96:continue
		var dot: float=(-host.camera.global_basis.z).dot(delta.normalized())
		if dot<best_dot:continue
		var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,sprites[i].global_position,1,[host.player.get_rid()]);query.hit_from_inside=true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
		best=i;best_dot=dot
	return best
func use() -> bool:
	var i:=aimed()
	if i<0 or host.carried_collected.size()>=64:return false
	state.taken[i]=true;host.carried_collected.append(ITEMS[i]);present()
	host.pickup_notice_time=2.5;host.interaction_label.text="Dragon Blood taken. Use it to place a delayed explosive."
	return true
func interaction_hint() -> String:return "E — Take Dragon Blood" if aimed()>=0 else ""
func _physics_process(delta: float) -> void:advance(delta)
func _process(_delta: float) -> void:present()
