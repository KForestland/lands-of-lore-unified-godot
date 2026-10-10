extends RefCounted
## Dawn spell 7: chain bolt. Spark SPELL.ODF family 4, effect 7, vtable 0x6478. A pure lifecycle module (modern adapter)
## for LOLG constructor 0x10A9D0, target list 0x10ACC4, update 0x10B044, hop 0x10B1D8 and collision 0x10B2D8.
## - targets() equals the executed original list builder on 600 cases (tests/fixtures/dawn_spell7_targets_native.json).
## - The hop/termination rules follow the disassembly (opus/spell7_58/AUDIT.md).
## Everything outside the module is returned as an effect for its owner:
## - "move": shared projectile motion at speed 150 (1118F4/DD8F4 owner);
## - "spawn_hop": a Spark-class hop child, effect 0x54. With a target, its stored-target producer 0x10A1D8 sends
##   HOP_REQUEST to the target's receiver (executed: mask 0x11, signature 1, mode 2, subtype 0x54, amount 10). Without
##   one it is visual only.
## - "cue": presentation string slot;
## - "destroy".
## Health/receiver handling, the world query (B23BC within RADIUS) and the shared clock (step) are supplied by owners.
const Heading=preload("res://scripts/lol2/dawn_heading.gd")
const RADIUS:=1280<<16
const MAX_CANDIDATES:=20
const SPEED:=150
const ARRIVAL:=0x1E0000              # arrive within 30 units (or within one step)
const OVERSHOOT:=0x7000              # heading swing that counts as passing the target
const COLLISION_TURN:=0x4000         # on collision, next targets needing a sharper turn are skipped (each spends a hop)
const HOP_CUE:=0x10C
const HOP_REQUEST:={"mask":0x11,"signature":1,"mode":2,"subtype":0x54,"amount":10}
## Hop child contact producer 0x10A28C (executed): two requests to an object the child touches.
const CONTACT_REQUESTS:=[{"mask":1,"signature":1,"mode":2,"subtype":0x54,"amount":2},{"mask":0x10,"signature":1,"mode":2,"subtype":0x54,"amount":3}]

## Hop count from the shared RNG draw in 0..0x5F (12415C(0x221D8, 0, 0x5F)): 3..5.
static func hop_limit(draw: int) -> int: return (clampi(draw,0,0x5F)>>5)+3

static func planar(a: Array, b: Array) -> int:
	return int(Vector2((float(b[0])-float(a[0]))/65536.0,(float(b[1])-float(a[1]))/65536.0).length()*65536.0)

## Target list. candidates: world query result in order, each {id, position:[x,y] 16.16, valid, targetable, type}.
## owner/current: ids or null. Returns {targets: 20 ids-or-null, limit}.
static func targets(candidates: Array, owner: Variant, current: Variant, limit: int, point: Array) -> Dictionary:
	var ok:=func(c: Dictionary) -> bool: return bool(c.valid) and bool(c.targetable)
	var list: Array=[];var dist: Array=[];var k:=0
	while k<candidates.size() and list.size()<MAX_CANDIDATES:
		var c: Dictionary=candidates[k]
		if c.id!=current and ok.call(c) and c.id!=owner: list.append(c);dist.append(planar(point,c.position))
		if list.size()==MAX_CANDIDATES: break
		k+=1
	if not list.is_empty():
		var far:=_farthest(dist)
		while k<candidates.size():
			var c: Dictionary=candidates[k];k+=1
			if c.id==owner or not ok.call(c) or c.id==current: continue
			var d:=planar(point,c.position)
			if d<int(dist[far]): list[far]=c;dist[far]=d;far=_farthest(dist)
	var order: Array=range(list.size())
	order.sort_custom(func(a,b): return int(dist[a])<int(dist[b]) or (int(dist[a])==int(dist[b]) and a<b))
	var out: Array=[];var types: Array=[]
	for j in order: out.append(list[j].id);types.append(int(list[j].type))
	var n:=out.size()
	for idx in range(limit,n):
		if types[idx]!=2: continue
		var j:=limit-1
		while j>=0 and types[j]==2: j-=1
		if j>=0: out[j]=out[idx];types[j]=2
	out.resize(MAX_CANDIDATES)
	if n<limit:
		if current!=null: out[n]=current;n+=1
		if n==1: limit=1
		else:
			for t in range(n,limit): out[t]=out[t-n]
	return {"targets":out,"limit":limit}

static func _farthest(dist: Array) -> int:
	var best:=0
	for j in range(1,dist.size()):
		if int(dist[j])>int(dist[best]): best=j
	return best

## state: list/limit from targets(); hop counter; current target; heading; pending visual hop; ended.
static func initial(owner: Variant, built: Dictionary, heading: int) -> Dictionary:
	return {"version":1,"owner":owner,"list":built.targets.duplicate(),"limit":int(built.limit),"hops":0,
		"target":built.targets[0],"heading":heading,"turned":false,"pending":false,"ended":false}

## One update. ctx: {position:[x,y], step: this tick's motion distance (shared clock), positions: {id:[x,y]}}.
static func step(s: Dictionary, ctx: Dictionary) -> Array:
	var fx: Array=[]
	if s.pending:
		fx.append({"type":"spawn_hop","owner":s.owner,"target":null,"at":ctx.position});s.pending=false
	if s.ended: fx.append({"type":"destroy"});return fx
	if s.target!=null:
		var at: Array=ctx.positions[s.target]
		var d:=planar(ctx.position,at)
		if d<=int(ctx.step) or d<=ARRIVAL:
			if not _hop(s,fx): return fx
		var old:=int(s.heading)
		s.heading=int(Heading.between(ctx.position,ctx.positions[s.target]).word)
		if s.turned:
			if absi(old-int(s.heading))>=OVERSHOOT:
				if not _hop(s,fx): return fx
				s.heading=int(Heading.between(ctx.position,ctx.positions[s.target]).word)
		else: s.turned=true
	fx.append({"type":"move","heading":int(s.heading),"speed":SPEED})
	return fx

## 0x10B1D8: hit the reached target, then chain to the next or end.
static func _hop(s: Dictionary,fx: Array) -> bool:
	fx.append({"type":"spawn_hop","owner":s.owner,"target":s.target,"request":HOP_REQUEST})
	s.hops=int(s.hops)+1
	if int(s.hops)>=int(s.limit) or s.list[s.hops]==null:
		fx.append({"type":"destroy"});s.ended=true;return false
	s.target=s.list[s.hops];s.turned=false
	fx.append({"type":"cue","slot":HOP_CUE})
	return true

## 0x10B2D8: the bolt touched something other than its target. ctx as step().
static func collide(s: Dictionary, ctx: Dictionary) -> void:
	s.pending=true
	s.hops=int(s.hops)+1
	if int(s.hops)>=int(s.limit): s.ended=true;return
	if s.target==null:
		s.target=s.list[s.hops]
		if s.target==null: s.ended=true
		return
	var bearing:=func(id) -> int: return int(Heading.between(ctx.position,ctx.positions[id]).word)
	var old: int=bearing.call(s.target)
	s.target=s.list[s.hops];s.hops=int(s.hops)+1
	if s.target==null: s.ended=true;return
	while absi(old-bearing.call(s.target))>COLLISION_TURN and s.target!=null:
		s.hops=int(s.hops)+1
		if int(s.hops)>=int(s.limit): s.ended=true;return
		old=bearing.call(s.target)
		s.target=s.list[s.hops]
		if s.target==null: s.ended=true;return
	if int(s.limit)<=int(s.hops): s.ended=true
