extends RefCounted
## Source64 normal region/event20 dialogue and native first-match held-item response.
## Local clocks are a modern adapter; original segment endpoints emit event0.
const SOURCE="res://scripts/lol2/jungle_kelsrick_source.json"
const MEDIA="res://assets/lol2/generated/jungle_kelsrick/media.json"
static func source() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func media() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
static func initial(src: Dictionary) -> Dictionary:
	var locals: Dictionary={}
	for n in src.owned_locals:locals[str(int(n))]=0
	# Event9 group31170 grants a sword to actor64 and selects pose9. Not player loot.
	return {"version":1,"locals":locals,"owner_state":0,"health":int(src.actor.health),"flags":int(src.actor.flags),"b5":0,"selector":9,"present":true,"items":["6-Fine longswd"],"clip":{},"hit_latches":[],"region":-1,"village_admitted":false,"death":0.0}
static func integer(v: Variant,lo: int,hi: int) -> bool:return (v is int or v is float) and is_finite(float(v)) and v==floor(float(v)) and v>=lo and v<=hi
## Values the pinned source can write to actor64: op16 owner states and op13 sub4 poses (plus initial 0/9,
## and death selector16 from A7544/hit). B5 is only touched by op13 sub6/7/10..13: bits 0x01|0x0C.
static func reachable(src: Dictionary) -> Dictionary:
	var states: Array=[0];var poses: Array=[9,16]
	for g in src.groups:
		for c in g.commands:
			var b: PackedByteArray=str(c.raw_hex).hex_decode()
			if b.size()<6 or b[1]!=2 or b.decode_u16(2)!=64:continue
			if b[0]==16 and int(b[4]) not in states:states.append(int(b[4]))
			if b[0]==13 and b[4]==4 and int(b[5]) not in poses:poses.append(int(b[5]))
	return {"states":states,"poses":poses}
static func validate(s: Variant,src: Dictionary,m: Dictionary) -> String:
	if not s is Dictionary or s.size()!=14 or not integer(s.get("version"),1,1):return "Invalid Kelsrick version."
	for k in ["owner_state","b5"]:
		if not integer(s.get(k),0,255):return "Invalid Kelsrick byte."
	var reach:=reachable(src)
	if int(s.owner_state) not in reach.states or (int(s.b5)&~13)!=0:return "Unreachable Kelsrick owner state."
	if not integer(s.get("selector"),0,24) or int(s.selector) not in reach.poses:return "Unreachable Kelsrick pose."
	if integer(s.get("health"),0,0) and (int(s.selector)!=16 or not (s.get("clip") is Dictionary and s.clip.is_empty())):return "Dead Kelsrick must hold the death pose."
	if integer(s.get("health"),1,int(src.actor.health)) and int(s.selector)==16:return "Living Kelsrick in the death pose."
	if not integer(s.get("health"),0,int(src.actor.health)) or not integer(s.get("flags"),0,65535) or not integer(s.get("selector"),0,24) or not integer(s.get("region"),-1,65535):return "Invalid Kelsrick actor."
	if not s.get("present") is bool or not s.get("village_admitted") is bool:return "Invalid Kelsrick latch."
	if not s.get("locals") is Dictionary or s.locals.size()!=src.owned_locals.size():return "Invalid Kelsrick locals."
	for n in src.owned_locals:
		if not integer(s.locals.get(str(int(n))),0,255):return "Invalid Kelsrick local."
	if s.get("items")!=["6-Fine longswd"]:return "Invalid Kelsrick actor inventory."
	if not s.get("hit_latches") is Array:return "Invalid Kelsrick hit latches."
	var seen: Array=[]
	for n in s.hit_latches:
		if not integer(n,0,65535) or int(n) not in [30402,30456,30544] or int(n) in seen:return "Invalid Kelsrick hit latch."
		seen.append(int(n))
	var death=s.get("death")
	if not (death is float or death is int) or not is_finite(float(death)) or death<0 or death>10 or (s.health>0 and death!=0):return "Invalid Kelsrick death clock."
	var c=s.get("clip")
	if not c is Dictionary:return "Invalid Kelsrick clip."
	if not c.is_empty():
		if c.size()!=3 or not integer(c.get("selector"),9,15) or not integer(c.get("segment"),0,255):return "Invalid Kelsrick clip selector."
		var row: Dictionary=m.clips.get(str(int(c.selector)),{});var segment: Dictionary={}
		for candidate in row.get("segments",[]):
			if int(candidate.index)==int(c.segment):segment=candidate
		if segment.is_empty():return "Unknown Kelsrick segment."
		var elapsed=c.get("elapsed")
		if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>float(segment.duration):return "Invalid Kelsrick clip clock."
		if int(c.selector)!=int(s.selector) or s.health==0:return "Kelsrick clip disagrees with actor."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true)
	for k in ["version","owner_state","health","flags","b5","selector","region"]:r[k]=int(r[k])
	r.death=float(r.death)
	for k in r.locals:r.locals[k]=int(r.locals[k])
	r.hit_latches=r.hit_latches.map(func(v):return int(v))
	if not r.clip.is_empty():r.clip={"selector":int(r.clip.selector),"segment":int(r.clip.segment),"elapsed":float(r.clip.elapsed)}
	return r
static func operand(s: Dictionary,o: Dictionary,ctx: Dictionary) -> int:
	if o.has("immediate"):return int(o.immediate)
	if o.has("owner_state"):return int(s.owner_state)
	if o.has("local"):return int(s.locals.get(str(int(o.local)),ctx.get("locals",{}).get(str(int(o.local)),0)))
	if o.has("shared"):return int(ctx.get("shared",{}).get(str(int(o.shared)),0))
	if o.has("expression"):return int(predicate(s,o.expression,ctx))
	return 0
static func predicate(s: Dictionary,p: Dictionary,ctx: Dictionary) -> bool:
	var a:=operand(s,p.left,ctx);var b:=operand(s,p.right,ctx)
	match p.op:
		"==":return a==b
		"!=":return a!=b
		"<":return a<b
		">":return a>b
		"<=":return a<=b
		">=":return a>=b
		"AND":return a!=0 and b!=0
		"OR":return a!=0 or b!=0
	return false
static func select(s: Dictionary,src: Dictionary,kind: String,owner: int,event: int,value: int,ctx: Dictionary) -> Array:
	var queue: Array=[]
	for g in src.groups:
		if g.owner_kind!=kind or int(g.owner)!=owner or int(g.event)!=event or (int(g.value)&255)!=(value&255):continue
		if g.predicate!=null and not predicate(s,src.predicates[str(int(g.predicate))],ctx):continue
		queue.append(g)
	return queue
static func actor_event(s: Dictionary,src: Dictionary,event: int,ctx: Dictionary) -> Array:return run(s,src,select(s,src,"actor",64,6,event,ctx),ctx)
static func enter_region(s: Dictionary,src: Dictionary,region: int,ctx: Dictionary) -> Array:
	if int(s.region)==region:return []
	s.region=region
	return run(s,src,select(s,src,"region",region,2,0,ctx),ctx)
static func village_admission(s: Dictionary) -> void:
	if s.village_admitted:return
	s.village_admitted=true;s.flags=int(s.flags)|0x4000 # Group4354 op9 property17, nativeB50FB.
static func offer(s: Dictionary,src: Dictionary,held: bool,ctx: Dictionary) -> Array:
	if not held or not s.present or s.health<=0 or (int(s.flags)&0x8000)!=0:return []
	# Sole kind4 source record mode1 requires nonempty held item. Native returns after first accepted record.
	var q:=select(s,src,"actor",64,4,1,ctx)
	return run(s,src,[q[0]] if not q.is_empty() else [],ctx)
static func hit(s: Dictionary,src: Dictionary,mask0: int,mask2: int,damage: int,ctx: Dictionary) -> Array:
	if not s.present or s.health<=0 or damage<=0:return []
	var queue: Array=[]
	for r in src.records:
		if int(r.kind)!=9 or int(r.group) in s.hit_latches:continue
		var b: PackedByteArray=str(r.raw).hex_decode()
		if (b.decode_u16(4)!=0 and (mask0&b.decode_u16(4))==0) or (b.decode_u16(6)!=0 and (mask2&b.decode_u16(6))==0) or damage<int(b[8]):continue
		if r.predicate!=null and not predicate(s,src.predicates[str(int(r.predicate))],ctx):continue
		for g in src.groups:
			if int(g.group)==int(r.group):queue.append(g)
		if b[9]&128:s.hit_latches.append(int(r.group))
	var effects:=run(s,src,queue,ctx)
	if s.health>0:s.health=maxi(0,int(s.health)-damage)
	if s.health==0 and s.selector!=16:
		s.selector=16;s.clip={};s.death=0.0;effects.append_array(actor_event(s,src,11,ctx))
	return effects
static func advance(s: Dictionary,src: Dictionary,m: Dictionary,delta: float,ctx: Dictionary) -> Array:
	if not is_finite(delta) or delta<=0:return []
	if s.health==0:s.death=minf(10.0,snappedf(float(s.death)+delta,1.0/1024));return []
	if s.clip.is_empty():return []
	var c: Dictionary=s.clip;var duration:=0.0
	for segment in m.clips[str(int(c.selector))].segments:
		if int(segment.index)==int(c.segment):duration=float(segment.duration)
	c.elapsed=minf(duration,snappedf(float(c.elapsed)+delta,1.0/4096))
	if c.elapsed<duration:return []
	s.clip={}
	return actor_event(s,src,0,ctx)
static func run(s: Dictionary,src: Dictionary,queue: Array,ctx: Dictionary) -> Array:
	var effects: Array=[];var guard:=0
	while not queue.is_empty() and guard<64:
		guard+=1;var g: Dictionary=queue.pop_front();effects.append({"type":"group","group":int(g.group)})
		for row in g.commands:
			var b: PackedByteArray=str(row.raw_hex).hex_decode();var target:=b.decode_u16(2);var own:=b[1]==2 and target==64
			match b[0]:
				198:
					if s.locals.has(str(b[4])):s.locals[str(b[4])]=int(b[5])
					else:effects.append({"type":"local","index":int(b[4]),"value":int(b[5])})
				199,206:effects.append({"type":"shared","index":int(b[4]),"op":"set" if b[0]==199 else "add","value":int(b[5]) if b[0]==199 or b[5]<128 else int(b[5])-256})
				16:
					if own:s.owner_state=int(b[4])
					else:effects.append({"type":"external","raw":row.raw_hex})
				8:
					if not own:effects.append({"type":"external","raw":row.raw_hex});continue
					match b[4]:
						1:s.clip={}
						9,10:s.clip={"selector":int(s.selector),"segment":int(b.decode_u16(6)),"elapsed":0.0};effects.append({"type":"clip"})
				9:
					if not own:effects.append({"type":"external","raw":row.raw_hex});continue
					match b[4]:
						2:s.present=false;s.clip={}
						3:s.present=true
						13:s.flags=int(s.flags)&0x7fff
						14:s.flags=int(s.flags)|0x8000
						17:s.flags=int(s.flags)|0x4000
						18:s.flags=int(s.flags)&0xbfff
						21:queue.append_array(select(s,src,"actor",64,6,20,ctx))
				13:
					if not own:effects.append({"type":"external","raw":row.raw_hex});continue
					match b[4]:
						4:s.selector=int(b[5]);s.clip={}
						6:s.b5=int(s.b5)|1
						7:s.b5=int(s.b5)&254
						10:s.b5=int(s.b5)&243 # A64F6 clears pending goal/action
						13:s.b5=(int(s.b5)&243)|12
						17:s.health=0;s.selector=16;s.clip={};s.death=0.0;queue.append_array(select(s,src,"actor",64,6,11,ctx))
				18:
					if b[1]==1:effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":row.raw_hex})
					else:effects.append({"type":"external","raw":row.raw_hex})
				3:
					# Actor-directed grant (group31170) stays actor inventory; player grants are host effects.
					if own:
						if "6-Fine longswd" not in s.items:s.items.append("6-Fine longswd")
					elif b[1]==1:effects.append({"type":"grant_player","identity":b.decode_u32(4),"count":b.decode_u32(8) if b.size()>=12 else 1,"raw":row.raw_hex})
					else:effects.append({"type":"external","raw":row.raw_hex})
				2:
					# Player properties (native D84D6): 0x26 scripted hold, 0x27 release.
					if b[1]==1:effects.append({"type":"player_property","property":int(b[4]),"value":int(b[5]),"raw":row.raw_hex})
					else:effects.append({"type":"external","raw":row.raw_hex})
				_:effects.append({"type":"external","raw":row.raw_hex})
	return effects
