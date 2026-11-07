extends Node3D
## Explicit modern adapter: place a fuse bomb ahead of the player; saved active-world clock,
## visible flask and blast, line-of-sight damage through existing creature/health owners.
const State=preload("res://scripts/lol2/dragon_blood_state.gd")
const ICON="res://assets/lol2/generated/museum_blood_loot/icon.png"
const RADIUS:=120.0
const DAMAGE:=20
var controller: Node
var host: Node3D
var sprites: Dictionary={}
var flashes: Array=[]
func setup(owner_controller: Node) -> void:
	controller=owner_controller;host=controller.host
func bombs() -> Array:return controller.state().get("dragon_blood",[])
func place(id: String) -> bool:
	if id not in State.ITEMS or host.scene_file_path not in State.AREAS or host.starting_magic.health()<=0:return false
	var start: Vector3=host.camera.global_position
	var end: Vector3=start-host.camera.global_basis.z*48.0
	var ray:=PhysicsRayQueryParameters3D.create(start,end,3,[host.player.get_rid()]);ray.hit_from_inside=true
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():end=hit.position+hit.normal*5.0
	var down:=PhysicsRayQueryParameters3D.create(end,end+Vector3.DOWN*100.0,1,[host.player.get_rid()])
	var floor_hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if floor_hit.is_empty():return false
	end=floor_hit.position+Vector3.UP*10
	var saved: Dictionary=controller.state()
	if not saved.has("dragon_blood"):saved.dragon_blood=[]
	saved.dragon_blood.append({"id":id,"area":host.scene_file_path,"position":[end.x,end.y,end.z],"remaining":State.FUSE})
	saved.spent.append(id);controller.carried().erase(id)
	present();return true
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0:return
	var saved: Dictionary=controller.state()
	var ready: Array=[]
	for bomb in bombs():
		if bomb.area!=host.scene_file_path:continue
		bomb.remaining=maxf(0,float(bomb.remaining)-delta)
		if bomb.remaining==0:ready.append(bomb.duplicate(true))
	# Commit retirement before any damage callback can replace player state or trigger a save.
	if saved.has("dragon_blood"):saved.dragon_blood=saved.dragon_blood.filter(func(b):return float(b.remaining)>0)
	for bomb in ready:explode(Vector3(bomb.position[0],bomb.position[1],bomb.position[2]))
	present()
func clear_to(point: Vector3,target: Vector3,body: Object=null) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(point,target,3,[])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or (body!=null and hit.collider==body)
func explode(point: Vector3) -> void:
	var aura=host.starting_magic.aura
	var targets: Dictionary=aura.targets()
	for id in targets:
		var target: Dictionary=targets[id]
		if point.distance_to(target.point)>RADIUS or not clear_to(point,target.point,target.body):continue
		# Existing aura receiver dispatch supports every live Act1 creature and magic progression.
		aura.hit(id,23,target) # Its highest modern attack is20 damage; no mana is charged.
	if point.distance_to(host.player.global_position)<=RADIUS and clear_to(point,host.camera.global_position,host.player) and not host.starting_magic.protected():
		host.starting_magic.set_health(maxi(0,host.starting_magic.health()-DAMAGE))
	var visual:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=3;sphere.height=6;visual.mesh=sphere
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(1,0.25,0.02,0.5);visual.material_override=material
	add_child(visual);visual.global_position=point;flashes.append({"node":visual,"remaining":0.3})
func present() -> void:
	if not is_instance_valid(host):return
	var active: Array=[]
	for bomb in bombs():
		if bomb.area!=host.scene_file_path:continue
		active.append(bomb.id)
		if not sprites.has(bomb.id):
			var sprite:=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(ICON));sprite.pixel_size=0.35;sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
			add_child(sprite);sprites[bomb.id]=sprite
		sprites[bomb.id].global_position=Vector3(bomb.position[0],bomb.position[1],bomb.position[2])
	for id in sprites.keys():
		if id not in active:sprites[id].queue_free();sprites.erase(id)
func _process(delta: float) -> void:
	present()
	if not is_instance_valid(host) or not host.starting_magic.world_active():return
	for f in flashes:
		f.remaining-=delta;f.node.scale=Vector3.ONE*(1+(0.3-f.remaining)*20)
		if f.remaining<=0:f.node.queue_free()
	flashes=flashes.filter(func(f):return f.remaining>0)
