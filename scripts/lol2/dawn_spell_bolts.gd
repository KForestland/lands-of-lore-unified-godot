extends Node3D
## Modern Chain bolt (Dawn spell 7) and Plasma bolt (Dawn spell 58). Classic Edition: playable behaviour, not native
## parity (docs/classic-edition.md). Reused evidence:
## - chain target ordering (dawn_spell7_chain.targets);
## - hop count 3..5 and arrival within 30 units;
## - hit requests: chain hop mask 0x11 / subtype 0x54 / 10; Plasma (Dawn selector 4) mask 0x11 / subtype 0x3A / 10.
## Modern choices (central constants below; tune in playtest):
## - plain homing at a fixed speed with swept rays (no native motion clock);
## - a wall ends a chain bolt and makes a Plasma bolt burst harmlessly;
## - lifetimes cap stray bolts;
## - glowing orb, light, hop arc and impact flash replace the original effect sprites.
## The host supplies targets and receives hit requests; health, defence and death stay with the health owner.
const Chain=preload("res://scripts/lol2/dawn_spell7_chain.gd")
const CHAIN:=7
const PLASMA:=58
## --- tuning (Classic Edition, modern) ---
const CHAIN_SPEED:=420.0
const PLASMA_SPEED:=300.0
const CHAIN_RADIUS:=1280.0          # candidate search around the first target (original radius)
const ARRIVAL:=30.0                 # original arrival distance
const LIFETIME:=6.0
const IMPACT_TIME:=0.45
const HOP_ARC_TIME:=0.25
const MAX_BOLTS:=8
const CHAIN_REQUEST:={"kind":"chain_hop","mask":0x11,"subtype":0x54,"amount":10}
const PLASMA_REQUEST:={"kind":"plasma","mask":0x11,"subtype":0x3A,"amount":10}
const PLASMA_HIT_TYPES:=[1,2,3,0x10]
const COLLISION_MASK:=3
## --- host links ---
## targets.call() -> Dictionary key -> {"body": PhysicsBody3D, "point": Vector3, "type": int (2 = creature/actor), "valid": bool}
var targets: Callable
## deliver.call(request: Dictionary) -> sends {kind, mask, subtype, amount, to (target key), source (caster key)}
var deliver: Callable
## RIDs bolts pass through (the caster's own body).
var exclude: Array=[]
var saved: Dictionary=initial()
var requests: Array=[]              # last delivered requests (diagnostics/tests)
var visuals: Dictionary={}
var flashes: Array=[]

static func initial() -> Dictionary: return {"version":1,"next_id":1,"bolts":[]}

static func _num(v: Variant, lo: float, hi: float) -> bool: return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi
static func _int(v: Variant, lo: int, hi: int) -> bool: return _num(v,lo,hi) and float(v)==floorf(float(v))
static func _vec(v: Variant) -> bool: return v is Array and v.size()==3 and v.all(func(x): return _num(x,-1000000,1000000))

static func validate(s: Variant) -> String:
	if not s is Dictionary or s.size()!=3 or s.get("version")!=1 or not _int(s.get("next_id"),1,0x7fffffff) or not s.get("bolts") is Array or s.bolts.size()>MAX_BOLTS:
		return "Invalid spell bolt state."
	var ids: Array=[]
	for b in s.bolts:
		if not b is Dictionary or b.size()!=12 or not _int(b.get("id"),1,int(s.next_id)-1) or int(b.id) in ids: return "Invalid spell bolt identity."
		ids.append(int(b.id))
		if not _int(b.get("kind"),0,255) or not int(b.kind) in [CHAIN,PLASMA] or not _vec(b.get("position")) or not _num(b.get("life"),0,LIFETIME) or not _num(b.get("impact"),0,IMPACT_TIME): return "Invalid spell bolt."
		for k in ["target","last"]:
			if not (b.get(k)==null or b.get(k) is String): return "Invalid spell bolt link."
		if not b.get("caster") is String or not b.get("hit") is bool: return "Invalid spell bolt link."
		if not b.get("list") is Array or b.list.size()>20 or b.list.any(func(k): return not k is String): return "Invalid chain target list."
		if not _int(b.get("limit"),1,20) or not _int(b.get("hops"),0,20) or int(b.hops)>int(b.limit): return "Invalid spell bolt progress."
		# Progress consistency: a chain's list is its hop sequence; a Plasma bolt has none and at most one hit.
		if int(b.kind)==CHAIN and (b.list.size()!=int(b.limit) or (b.target!=null and (int(b.hops)>=b.list.size() or b.list[int(b.hops)]!=b.target))): return "Invalid chain progress."
		if int(b.kind)==PLASMA and (not b.list.is_empty() or int(b.limit)!=1 or int(b.hops)>1): return "Invalid Plasma progress."
		if float(b.impact)>0 and (b.target!=null or not b.hit): return "Invalid spell bolt impact."
		if b.target==null and float(b.impact)==0: return "Invalid spell bolt target."
	return ""

func checkpoint() -> Dictionary: return saved.duplicate(true)
func restore(s: Variant) -> String:
	var error:=validate(s)
	if not error.is_empty(): return error
	# Canonical numbers after JSON (ints stay ints, clocks/positions floats) so a reload round-trips exactly.
	saved=s.duplicate(true);saved.version=1;saved.next_id=int(saved.next_id)
	for b in saved.bolts:
		for k in ["id","kind","limit","hops"]: b[k]=int(b[k])
		for k in ["life","impact"]: b[k]=float(b[k])
		b.position=b.position.map(func(v): return float(v))
	_present();return ""

func _targets() -> Dictionary:
	if targets.is_valid():
		var t=targets.call()
		if t is Dictionary: return t
	return {}

func _new_bolt(kind: int, caster: String, origin: Vector3, target: Variant) -> Dictionary:
	if saved.bolts.size()>=MAX_BOLTS: return {}
	var b:={"id":int(saved.next_id),"kind":kind,"caster":caster,"position":[origin.x,origin.y,origin.z],"target":target,
		"list":[],"limit":1,"hops":0,"life":LIFETIME,"impact":0.0,"hit":false,"last":null}
	saved.next_id=int(saved.next_id)+1;saved.bolts.append(b);return b

## Chain bolt aimed at first_target; hop_draw = shared RNG 0..95 (3..5 hops). Returns the bolt id or 0.
func cast_chain(caster: String, origin: Vector3, first_target: String, hop_draw: int) -> int:
	var all:=_targets()
	if not all.has(first_target): return 0
	var focus: Vector3=all[first_target].point
	var candidates: Array=[]
	for key in all:
		var t: Dictionary=all[key]
		if t.point.distance_to(focus)>CHAIN_RADIUS: continue
		candidates.append({"id":key,"position":[int(t.point.x*65536),int(t.point.z*65536)],"valid":bool(t.get("valid",true)),"targetable":true,"type":int(t.get("type",2))})
	var built:=Chain.targets(candidates,caster,first_target,Chain.hop_limit(hop_draw),[int(origin.x*65536),int(origin.z*65536)])
	var b:=_new_bolt(CHAIN,caster,origin,first_target)
	if b.is_empty(): return 0
	# Modern hop order (deliberate change): the first target leads, then each distinct creature in the verified
	# nearest-first order; with fewer creatures than hops the sequence cycles, never striking the same one twice in a row.
	var seq: Array=[first_target]
	for k in built.targets:
		if k!=null and k not in seq: seq.append(k)
	var hops:=Chain.hop_limit(hop_draw)
	var list: Array=[]
	while list.size()<hops:
		for k in seq:
			if list.size()>=hops: break
			if list.is_empty() or list[-1]!=k: list.append(k)
		if seq.size()==1: break
	b.list=list;b.limit=list.size()
	_present();return int(b.id)

## Plasma bolt homing on target. Returns the bolt id or 0.
func cast_plasma(caster: String, origin: Vector3, target: String) -> int:
	var b:=_new_bolt(PLASMA,caster,origin,target)
	if b.is_empty(): return 0
	_present();return int(b.id)

## Requests are queued and delivered only after the bolt's progress (hop/impact/target) is committed, so a save taken
## inside the health callback can never replay the same hit.
var _outbox: Array=[]
func _send(base: Dictionary, to: String, caster: String) -> void:
	var r: Dictionary=base.duplicate();r.to=to;r.source=caster
	_outbox.append(r)
func _flush() -> void:
	while not _outbox.is_empty():
		var r: Dictionary=_outbox.pop_front()
		requests.append(r)
		if deliver.is_valid(): deliver.call(r)

func _key_for(rid: RID, all: Dictionary) -> String:
	for key in all:
		var body=all[key].get("body")
		if body!=null and is_instance_valid(body) and body.get_rid()==rid: return key
	return ""

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	var all:=_targets();var space:=get_world_3d().direct_space_state
	for b in saved.bolts.duplicate():
		if float(b.impact)>0:
			b.impact=maxf(0.0,float(b.impact)-delta)
			if float(b.impact)==0: saved.bolts.erase(b)
			continue
		b.life=maxf(0.0,float(b.life)-delta)
		if float(b.life)==0 or b.target==null or not all.has(b.target): _end(b);continue
		var from:=Vector3(b.position[0],b.position[1],b.position[2])
		var goal: Vector3=all[b.target].point
		var speed:=CHAIN_SPEED if int(b.kind)==CHAIN else PLASMA_SPEED
		var to:=from.move_toward(goal,speed*delta)
		# The creature it just struck is excluded from the sweep itself, so a wall behind it is still found.
		var hit:=_sweep(space,from,to,b,all)
		if not hit.is_empty():
			var key:=_key_for(hit.rid,all)
			if key!=b.target:
				b.position=[hit.position.x,hit.position.y,hit.position.z]
				_touch(b,key,all);_flush();continue
			to=goal
		b.position=[to.x,to.y,to.z]
		if to.distance_to(goal)<=ARRIVAL:
			# Proximity arrival needs a clear remaining path: something in between is touched instead.
			var rest:=_sweep(space,to,goal,b,all)
			if not rest.is_empty() and _key_for(rest.rid,all)!=b.target:
				b.position=[rest.position.x,rest.position.y,rest.position.z]
				_touch(b,_key_for(rest.rid,all),all)
			else: _arrive(b,all)
		_flush()
	_present()

func _sweep(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, b: Dictionary, all: Dictionary) -> Dictionary:
	var skip: Array[RID]=[];skip.assign(exclude)
	if b.last!=null and all.has(b.last) and all[b.last].get("body")!=null and is_instance_valid(all[b.last].body): skip.append(all[b.last].body.get_rid())
	if from.distance_to(to)<0.001: return {}
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,COLLISION_MASK,skip))

func _arrive(b: Dictionary, all: Dictionary) -> void:
	if int(b.kind)==PLASMA:
		_send(PLASMA_REQUEST,b.target,b.caster);_impact(b);return
	var reached: String=b.target
	_send(CHAIN_REQUEST,reached,b.caster)
	b.hops=int(b.hops)+1
	var next=null
	if int(b.hops)<int(b.limit) and int(b.hops)<b.list.size(): next=b.list[b.hops]
	if next==null or not all.has(next): _impact(b);return
	_arc(all[reached].point,all[next].point)
	b.target=next;b.last=reached

## Touched something other than its target (key "" = world geometry).
func _touch(b: Dictionary, key: String, all: Dictionary) -> void:
	if int(b.kind)==PLASMA:
		if key!="" and int(all[key].get("type",0)) in PLASMA_HIT_TYPES: _send(PLASMA_REQUEST,key,b.caster)
		_impact(b);return
	if key=="": _impact(b);return     # modern: a wall ends the chain
	b.hops=int(b.hops)+1;b.last=key   # a creature in the way takes a hop and is not re-contacted
	if int(b.hops)>=int(b.limit): _impact(b)
	elif b.list[b.hops]!=b.target: b.list[b.hops]=b.target   # keep the hop sequence pointing at the current target
	_send(CHAIN_REQUEST,key,b.caster)

func _impact(b: Dictionary) -> void:
	b.impact=IMPACT_TIME;b.target=null;b.hit=true
	_flash(Vector3(b.position[0],b.position[1],b.position[2]),int(b.kind))

func _end(b: Dictionary) -> void: saved.bolts.erase(b)

## ---- presentation (modern) ----
const COLORS:={CHAIN:Color(0.65,0.85,1.0),PLASMA:Color(0.8,0.3,1.0)}
func _orb(kind: int, radius: float) -> Node3D:
	var root:=Node3D.new();add_child(root)
	var mesh:=MeshInstance3D.new();var s:=SphereMesh.new();s.radius=radius;s.height=radius*2;mesh.mesh=s
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=COLORS[kind]
	m.emission_enabled=true;m.emission=COLORS[kind];mesh.material_override=m;root.add_child(mesh)
	# Soft additive halo so the bolt reads at gameplay distance.
	var halo:=MeshInstance3D.new();var hs:=SphereMesh.new();hs.radius=radius*2.4;hs.height=radius*4.8;halo.mesh=hs
	var hm:=StandardMaterial3D.new();hm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;hm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;hm.albedo_color=Color(COLORS[kind],0.35);halo.material_override=hm;root.add_child(halo)
	var light:=OmniLight3D.new();light.light_color=COLORS[kind];light.omni_range=radius*30;light.light_energy=4.0;root.add_child(light)
	return root

func _present() -> void:
	if not is_inside_tree(): return
	var live: Array=[]
	for b in saved.bolts:
		if float(b.impact)>0: continue
		live.append(int(b.id))
		if not visuals.has(int(b.id)): visuals[int(b.id)]=_orb(int(b.kind),8.0 if int(b.kind)==CHAIN else 12.0)
		visuals[int(b.id)].global_position=Vector3(b.position[0],b.position[1],b.position[2])
	for id in visuals.keys():
		if id not in live: visuals[id].queue_free();visuals.erase(id)

func _flash(at: Vector3, kind: int) -> void:
	if not is_inside_tree(): return
	var f:=_orb(kind,14.0);f.global_position=at;flashes.append(f)
	var tween:=f.create_tween();tween.tween_property(f,"scale",Vector3.ONE*2.2,IMPACT_TIME);tween.tween_callback(func(): flashes.erase(f);f.queue_free())

func _arc(a: Vector3, b: Vector3) -> void:
	if not is_inside_tree() or a.distance_to(b)<1: return
	var arc:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=3.0;c.bottom_radius=3.0;c.height=a.distance_to(b);arc.mesh=c
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=Color(0.85,0.95,1.0);m.emission_enabled=true;m.emission=COLORS[CHAIN];arc.material_override=m
	add_child(arc);arc.global_position=(a+b)/2.0
	arc.look_at(b,Vector3.UP if absf((b-a).normalized().y)<0.99 else Vector3.RIGHT);arc.rotate_object_local(Vector3.RIGHT,PI/2)
	flashes.append(arc)
	get_tree().create_timer(HOP_ARC_TIME).timeout.connect(func(): flashes.erase(arc);arc.queue_free())
