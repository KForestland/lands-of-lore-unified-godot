extends Node3D
## Modern demo combat, driven by the encounter's existing world update.
## Deliberate tuning for the playable 30-health scale; not native timing parity.
const SPEED:=340.0
const RANGE:=1200.0
const INTERVAL:=2.2
const WINDUP:=0.65
const LIFETIME:=5.0
const REQUEST_DAMAGE:=15
const Defense=preload("res://scripts/lol2/player_defense.gd")
const Numbers=preload("res://scripts/lol2/save_value_rules.gd")
var dawn: Node3D
var saved: Dictionary=initial()
var visuals: Dictionary={}
var charge: MeshInstance3D
static func initial() -> Dictionary:return {"version":1,"cooldown":0.8,"windup":0.0,"shots":0,"bolts":[]}
static func finite_number(v: Variant, lo: float, hi: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi
static func validate(s: Variant) -> String:
	if not s is Dictionary or s.size()!=5 or s.get("version")!=1:return "Invalid Dawn combat state."
	if not finite_number(s.get("cooldown"),0,INTERVAL) or not finite_number(s.get("windup"),0,WINDUP):return "Invalid Dawn cast timer."
	if not Numbers.integer(s.get("shots"),0x7fffffff) or not s.get("bolts") is Array or s.bolts.size()>8:return "Invalid Dawn projectile list."
	var ids: Array=[]
	for b in s.bolts:
		if not b is Dictionary or b.size()!=4 or not Numbers.integer(b.get("id"),int(s.shots)) or int(b.id)<1 or int(b.id) in ids:return "Invalid Dawn projectile identity."
		ids.append(int(b.id))
		if not finite_number(b.get("life"),0,LIFETIME):return "Invalid Dawn projectile lifetime."
		for key in ["position","velocity"]:
			if not b.get(key) is Array or b[key].size()!=3:return "Invalid Dawn projectile vector."
			for v in b[key]:
				if not finite_number(v,-1000000,1000000):return "Invalid Dawn projectile coordinate."
		if Vector3(b.velocity[0],b.velocity[1],b.velocity[2]).length()>SPEED+0.01:return "Invalid Dawn projectile speed."
	return ""
func checkpoint() -> Dictionary:return saved.duplicate(true)
func restore(s: Dictionary) -> void:
	saved=s.duplicate(true);saved.version=1;saved.shots=int(saved.shots)
	saved.cooldown=float(saved.cooldown);saved.windup=float(saved.windup)
	for b in saved.bolts:
		b.id=int(b.id);b.life=float(b.life)
		b.position=b.position.map(func(v):return float(v))
		b.velocity=b.velocity.map(func(v):return float(v))
	present()
func point(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func array(v: Vector3) -> Array:return [snappedf(v.x,1.0/1024),snappedf(v.y,1.0/1024),snappedf(v.z,1.0/1024)]
func sphere(radius: float) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;node.mesh=mesh
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,0.35,0.06);node.material_override=material
	add_child(node);return node
func present() -> void:
	if dawn==null:return
	var active: Array=[]
	for b in saved.bolts:
		active.append(int(b.id))
		if not visuals.has(int(b.id)):visuals[int(b.id)]=sphere(7)
		visuals[int(b.id)].global_position=point(b.position)
	for id in visuals.keys():
		if id not in active:visuals[id].queue_free();visuals.erase(id)
	if charge==null:charge=sphere(10)
	charge.visible=float(saved.windup)>0
	if dawn.population!=null:charge.global_position=dawn.population.bodies[dawn.ID].global_position+Vector3.UP*40
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0 or dawn==null or not dawn.world_active() or get_tree().paused:return
	if not dawn.hostile():
		saved.bolts.clear();saved.windup=0.0;present();return
	var host=dawn.host
	var body: Node3D=dawn.population.bodies[dawn.ID]
	var space:=get_world_3d().direct_space_state
	var excluded: Array[RID]=[body.get_rid()]
	# Swept segments cannot skip walls/player at normal or large frame deltas.
	for bolt in saved.bolts.duplicate():
		var from:=point(bolt.position);var to:=from+point(bolt.velocity)*minf(delta,float(bolt.life))
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,3,excluded))
		bolt.life=maxf(0,snappedf(float(bolt.life)-delta,1.0/1024));bolt.position=array(to)
		if not hit.is_empty() or float(bolt.life)<=0:
			saved.bolts.erase(bolt) # Consume before callbacks or save observers.
			if not hit.is_empty() and hit.get("rid")==host.player.get_rid():
				var loss: int=0 if host.starting_magic.protected() else Defense.incoming(host,REQUEST_DAMAGE,4)
				host.starting_magic.set_health(maxi(0,host.starting_magic.health()-loss))
		if host.starting_magic.health()<=0:break
	if host.starting_magic.health()<=0:present();return
	if dawn.talking() or dawn.movement_locked():saved.windup=0.0;present();return
	var muzzle: Vector3=body.global_position+Vector3.UP*40
	var target: Vector3=host.player.global_position
	var ray:=space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle,target,3,excluded))
	var visible: bool=muzzle.distance_to(target)<=RANGE and not ray.is_empty() and ray.get("rid")==host.player.get_rid()
	if not visible:saved.windup=0.0;present();return
	if float(saved.windup)>0:
		saved.windup=maxf(0,snappedf(float(saved.windup)-delta,1.0/1024))
		if float(saved.windup)==0 and saved.bolts.size()<8 and int(saved.shots)<0x7fffffff:
			saved.shots+=1
			saved.bolts.append({"id":saved.shots,"position":array(muzzle),"velocity":array(muzzle.direction_to(target)*SPEED),"life":LIFETIME})
			saved.cooldown=INTERVAL
	else:
		saved.cooldown=maxf(0,snappedf(float(saved.cooldown)-delta,1.0/1024))
		if float(saved.cooldown)==0:saved.windup=WINDUP
	present()
