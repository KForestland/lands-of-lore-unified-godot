extends Node3D
## Modern demo combat, driven by the encounter's existing world update.
## Deliberate tuning for the playable 30-health scale; not native timing parity.
## Dawn rotates three ranged spells on the same cadence and telegraph:
## - the orange bolt (always the first shot);
## - the Chain bolt (spell 7);
## - the Plasma bolt (spell 58).
## Chain and Plasma run in dawn_spell_bolts.gd; their hit requests come back here and are applied through the same
## defence and aura path as the orange bolt (docs/dawn-spell-bolts.md).
const SPEED:=340.0
const RANGE:=1200.0
const INTERVAL:=2.2
const WINDUP:=0.65
const LIFETIME:=5.0
const REQUEST_DAMAGE:=15
## Raw damage into Defense.incoming(host, raw, 4), the same scale as the orange bolt (modern tuning for 30 health):
## - the Chain bolt is fast and harder to dodge, so it hits lighter;
## - the Plasma bolt is slow and dodgeable, so it hits harder.
const CHAIN_DAMAGE:=12
const PLASMA_DAMAGE:=20
const SPELLS:=["bolt","chain","plasma"]
const SPELL_COLORS:={"bolt":Color(1,0.35,0.06),"chain":Color(0.65,0.85,1.0),"plasma":Color(0.8,0.3,1.0)}
const Bolts=preload("res://scripts/lol2/dawn_spell_bolts.gd")
const Defense=preload("res://scripts/lol2/player_defense.gd")
const Numbers=preload("res://scripts/lol2/save_value_rules.gd")
var dawn: Node3D
var saved: Dictionary=initial()
var visuals: Dictionary={}
var charge: MeshInstance3D
var spells: Node3D
static func initial() -> Dictionary:return {"version":1,"cooldown":0.8,"windup":0.0,"shots":0,"bolts":[],"rotation":0,"spells":Bolts.initial()}
## Older saves carry the five-key orange-bolt state; they load with rotation 0 and no spell bolts.
static func upgrade(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true)
	if r.size()==5:r.rotation=0;r.spells=Bolts.initial()
	return r
static func finite_number(v: Variant, lo: float, hi: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi
static func validate(s: Variant) -> String:
	if not s is Dictionary or not s.size() in [5,7] or s.get("version")!=1:return "Invalid Dawn combat state."
	if s.size()==7:
		if not Numbers.integer(s.get("rotation"),SPELLS.size()-1):return "Invalid Dawn spell rotation."
		var spell_error:=Bolts.validate(s.get("spells"))
		if not spell_error.is_empty():return spell_error
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
func checkpoint() -> Dictionary:
	if spells!=null:saved.spells=spells.checkpoint()
	return saved.duplicate(true)
func _ensure_spells() -> void:
	if spells!=null or dawn==null:return
	spells=Bolts.new();spells.name="Spells";add_child(spells)
	spells.targets=func():
		var host=dawn.host
		if host==null or host.player==null:return {}
		return {"player":{"body":host.player,"point":host.player.global_position,"type":2,"valid":true}}
	spells.deliver=_spell_hit
func restore(s: Dictionary) -> void:
	saved=upgrade(s);saved.version=1;saved.shots=int(saved.shots);saved.rotation=int(saved.rotation)
	_ensure_spells()
	if spells!=null:
		var spell_error: String=spells.restore(saved.spells)
		if not spell_error.is_empty():push_error(spell_error)
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
	# The telegraph shows which spell is coming.
	charge.material_override.albedo_color=SPELL_COLORS[SPELLS[int(saved.get("rotation",0))]]
	if dawn.population!=null:charge.global_position=dawn.population.bodies[dawn.ID].global_position+Vector3.UP*40
## Chain/Plasma hit requests: same defence and aura path as the orange bolt; only hits on the player apply here.
func _spell_hit(request: Dictionary) -> void:
	if request.get("to")!="player" or dawn==null:return
	var host=dawn.host
	var raw: int=CHAIN_DAMAGE if request.get("kind")=="chain_hop" else PLASMA_DAMAGE
	var loss: int=0 if host.starting_magic.protected() else Defense.incoming(host,raw,4)
	host.starting_magic.set_health(maxi(0,host.starting_magic.health()-loss))
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0 or dawn==null or not dawn.world_active() or get_tree().paused:return
	_ensure_spells()
	if not dawn.hostile():
		saved.bolts.clear();saved.windup=0.0
		if spells!=null:spells.restore(Bolts.initial())
		present();return
	var host=dawn.host
	var body: Node3D=dawn.population.bodies[dawn.ID]
	var space:=get_world_3d().direct_space_state
	var excluded: Array[RID]=[body.get_rid()]
	spells.exclude=[body.get_rid()]
	spells.advance(delta)
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
			var spell: String=SPELLS[int(saved.rotation)]
			var cast:=true
			match spell:
				"bolt":saved.bolts.append({"id":saved.shots+1,"position":array(muzzle),"velocity":array(muzzle.direction_to(target)*SPEED),"life":LIFETIME})
				"chain":cast=spells.cast_chain("dawn",muzzle,"player",(int(saved.shots)*37)%96)>0
				"plasma":cast=spells.cast_plasma("dawn",muzzle,"player")>0
			if cast:saved.shots+=1;saved.rotation=(int(saved.rotation)+1)%SPELLS.size()
			saved.cooldown=INTERVAL
	else:
		saved.cooldown=maxf(0,snappedf(float(saved.cooldown)-delta,1.0/1024))
		if float(saved.cooldown)==0:saved.windup=WINDUP
	present()
