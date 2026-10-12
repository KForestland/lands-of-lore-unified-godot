extends RefCounted
## Huline Jungle Bacatta branch (prop552 → Bacatta61 → guard60 → prop4398 event20) from pinned groups.
## Pure saved state. The caller supplies producers and presents the returned effects.
## Native rules: ADDE0 predicates at queue time, FIFO groups; opcode13 B5 bits (A6348);
## opcode16 byte25; opcode198/207 locals, opcode206/199 shared (signed, 0..255, host caps);
## opcode14 operation3/4 by ordinal (B485C/B494B); kind8 = sound request finished on the owner
## (AE510 from the sound manager); event22 = behavior7 path end (A3CFE, hive_path_control.gd);
## kind9 prop552 = AE2C8 mode4 (context+0x26 <= threshold, special byte 0x23331==5 supplied);
## op9 property22 = lock + player+0x81 escort (B546A/D4D1E); player property0x31 releases it (D83D7);
## kind10 = owner movement into region word (B028A enter, verified for the captain by Codex).
## Adapters (documented): op8 load/start clip end = event0; op13 sub4 sprite pose cycle end = event3;
## Bacatta walk speed/arrival radius; clip/sound durations from the staged media manifest.
const EventTimer = preload("res://scripts/lol2/hive_event_timer.gd")
const PathControl = preload("res://scripts/lol2/hive_path_control.gd")
const SOURCE := "res://scripts/lol2/jungle_bacatta_source.json"
const MEDIA := "res://assets/lol2/generated/jungle_bacatta_media/media.json"
const WALK_SPEED := 48.0
const ARRIVAL := 8.0
const POSE_FPS := 8.0
const POSE7_FRAMES := 10
const MAX_SOUNDS := 8

static func source(path: String=SOURCE) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

## Clip and sound durations from the staged original media (seconds).
static func timing(path: String=MEDIA) -> Dictionary:
	var media: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not media is Dictionary: return {}
	var clips: Dictionary={}
	for owner in media.clips:
		for selector in media.clips[owner]:
			var c: Dictionary=media.clips[owner][selector]
			clips["%s:%s"%[owner,selector]]=float(c.duration)
			for seg in c.get("segments",[]): clips["%s:%s:%d"%[owner,selector,int(seg.index)]]=float(seg.duration)
	var sounds: Dictionary={}
	for request in media.sounds: sounds[str(request)]=float(media.sounds[request].duration)
	return {"clips":clips,"sounds":sounds}

static func initial(src: Dictionary) -> Dictionary:
	var timers: Dictionary={}
	for t in src.timers: timers[str(int(t.ordinal))]={"version":1,"flags":int(t.flags),"remaining":int(t.countdown)}
	var spawn: Array=src.bacatta.position
	return {"version":1,"locals":{"37":0,"51":0},
		"prop552":{"present":bool(src.prop552.present),"state":0,"selector":-1,"clip":{},"repeat":false,"armed":true},
		"bacatta":{"present":false,"state":0,"b5":0,"goal":-1,"action":-1,"selector":-1,"clip":{},"pose":{},
			"path_index":0,"position":[float(spawn[0]),float(spawn[2])],"region":-1,"walking":false},
		"guard60":{"state":0,"selector":-1,"clip":{},"pose":{}},
		"timers":timers,"sounds":[],"escort":false,"ending_requested":false,"ticks_fraction":0.0,"rng":1}

## ---- validation --------------------------------------------------------------------------
static func _int(value: Variant, maximum: int, minimum: int=0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum

static func _num(value: Variant, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0.0 and float(value)<=maximum

static func _clip_key(owner: String, clip: Dictionary) -> String:
	return "%s:%d"%[owner,int(clip.selector)] if int(clip.segment)<0 else "%s:%d:%d"%[owner,int(clip.selector),int(clip.segment)]

static func _valid_clip(clip: Variant, owner: String, t: Dictionary) -> bool:
	if not clip is Dictionary: return false
	if clip.is_empty(): return true
	if clip.size()!=3 or not _int(clip.get("selector"),255) or not _int(clip.get("segment"),255,-1): return false
	var key:=_clip_key(owner,clip)
	return t.clips.has(key) and _num(clip.get("elapsed"),float(t.clips[key]))

static func _valid_pose(pose: Variant) -> bool:
	if not pose is Dictionary: return false
	if pose.is_empty(): return true
	return pose.size()==2 and _int(pose.get("selector"),255) and _num(pose.get("elapsed"),POSE7_FRAMES/POSE_FPS)

static func validate(state: Variant, src: Dictionary, t: Dictionary) -> String:
	if t.is_empty(): return "Bacatta media timing is not staged."
	if not state is Dictionary or state.size()!=11 or not _int(state.get("version"),1,1): return "Invalid Bacatta version."
	var locals=state.get("locals")
	if not locals is Dictionary or locals.size()!=2 or not _int(locals.get("37"),255) or not _int(locals.get("51"),255): return "Invalid Bacatta locals."
	var p=state.get("prop552")
	if not p is Dictionary or p.size()!=6 or not p.get("present") is bool or not p.get("repeat") is bool or not p.get("armed") is bool: return "Invalid prop552 state."
	if not _int(p.get("state"),255) or not _int(p.get("selector"),255,-1) or not _valid_clip(p.get("clip"),"prop552",t): return "Invalid prop552 state."
	var b=state.get("bacatta")
	if not b is Dictionary or b.size()!=12 or not b.get("present") is bool or not b.get("walking") is bool: return "Invalid Bacatta actor."
	for key in ["state","b5"]:
		if not _int(b.get(key),255): return "Invalid Bacatta actor."
	for key in ["goal","action","selector"]:
		if not _int(b.get(key),255,-1): return "Invalid Bacatta actor."
	if not _int(b.get("path_index"),int(src.route.count)-1,-(int(src.route.count)-1)) or not _int(b.get("region"),65535,-1): return "Invalid Bacatta path."
	var pos=b.get("position")
	if not pos is Array or pos.size()!=2 or not (pos[0] is float or pos[0] is int) or not (pos[1] is float or pos[1] is int) or not is_finite(float(pos[0])) or not is_finite(float(pos[1])): return "Invalid Bacatta position."
	if not _valid_clip(b.get("clip"),"bacatta",t) or not _valid_pose(b.get("pose")): return "Invalid Bacatta presentation."
	var g=state.get("guard60")
	if not g is Dictionary or g.size()!=4 or not _int(g.get("state"),255) or not _int(g.get("selector"),255,-1) or not _valid_clip(g.get("clip"),"guard60",t) or not _valid_pose(g.get("pose")): return "Invalid guard60 state."
	var timers=state.get("timers")
	if not timers is Dictionary or timers.size()!=src.timers.size(): return "Invalid Bacatta timers."
	for row in src.timers:
		if EventTimer.restore(timers.get(str(int(row.ordinal)))).has("error"): return "Invalid Bacatta timer."
	var sounds=state.get("sounds")
	if not sounds is Array or sounds.size()>MAX_SOUNDS: return "Invalid Bacatta sounds."
	for s in sounds:
		if not s is Dictionary or s.size()!=2 or not _int(s.get("request"),65535) or not t.sounds.has(str(int(s.request))) or not _num(s.get("elapsed"),float(t.sounds[str(int(s.request))])): return "Invalid Bacatta sound."
	if not state.get("escort") is bool or not state.get("ending_requested") is bool: return "Invalid Bacatta flags."
	if state.escort and not b.present: return "Escort without Bacatta."
	var f=state.get("ticks_fraction")
	if not _num(f,0.999999999) or not _int(state.get("rng"),4294967295): return "Invalid Bacatta clock."
	return ""

static func canonical(state: Dictionary) -> Dictionary:
	var r: Dictionary=state.duplicate(true)
	r.version=1;r.rng=int(r.rng);r.ticks_fraction=float(r.ticks_fraction)
	for key in r.locals: r.locals[key]=int(r.locals[key])
	r.prop552.state=int(r.prop552.state);r.prop552.selector=int(r.prop552.selector)
	for key in ["state","b5","goal","action","selector","path_index","region"]: r.bacatta[key]=int(r.bacatta[key])
	r.bacatta.position=[float(r.bacatta.position[0]),float(r.bacatta.position[1])]
	r.guard60.state=int(r.guard60.state);r.guard60.selector=int(r.guard60.selector)
	for owner in [r.prop552,r.bacatta,r.guard60]:
		if not owner.clip.is_empty(): owner.clip={"selector":int(owner.clip.selector),"segment":int(owner.clip.segment),"elapsed":float(owner.clip.elapsed)}
	for owner in [r.bacatta,r.guard60]:
		if not owner.pose.is_empty(): owner.pose={"selector":int(owner.pose.selector),"elapsed":float(owner.pose.elapsed)}
	for key in r.timers: r.timers[key]=EventTimer.restore(r.timers[key]).checkpoint
	var sounds: Array=[]
	for s in r.sounds: sounds.append({"request":int(s.request),"elapsed":float(s.elapsed)})
	r.sounds=sounds
	return r

## ---- queries ---------------------------------------------------------------------------
## Hostile Bacatta fights when a decision is pending and unblocked (B5 0C set, bit01 clear) outside goal7.
static func bacatta_fighting(state: Dictionary) -> bool:
	var b: Dictionary=state.bacatta
	return b.present and int(b.goal) not in [7,15] and (int(b.b5)&12)!=0 and (int(b.b5)&1)==0

## Authoritative prop552 presence (region1921 link; branch/region4435/guard-hit removal).
static func prop_present(state: Dictionary) -> bool:
	return bool(state.prop552.present)

## Player escort target while property22 holds the lock (player auto-follows; input locked).
static func escort_target(state: Dictionary) -> Variant:
	return Vector2(float(state.bacatta.position[0]),float(state.bacatta.position[1])) if state.escort else null

## ---- supplied producers ---------------------------------------------------------------
## ctx: {"shared":{"0","12","13","14","18","25","47"}, "locals":{"41"}, "guard60":{"present":bool,"alive":bool}}
static func enter_region(state: Dictionary, src: Dictionary, t: Dictionary, region: int, ctx: Dictionary) -> Array:
	return _dispatch(state,src,t,"region",region,2,0,ctx)

## Other region events (for example region1921 event4 group3926, producer not traced).
static func region_event(state: Dictionary, src: Dictionary, t: Dictionary, region: int, event: int, value: int, ctx: Dictionary) -> Array:
	return _dispatch(state,src,t,"region",region,event,value,ctx)

## Player E-use on prop552 (kind4 value0 records; no item qualifier).
static func use(state: Dictionary, src: Dictionary, t: Dictionary, ctx: Dictionary) -> Array:
	if not state.prop552.present: return []
	return _dispatch(state,src,t,"prop",552,4,0,ctx)

## Hit on prop552: AE2C8 mode4, one-shot. hit: {"mask0","mask2","before","after","special"(byte 0x23331),"special_admitted"}.
static func hit(state: Dictionary, src: Dictionary, t: Dictionary, h: Dictionary, ctx: Dictionary) -> Array:
	var p: Dictionary=state.prop552
	if not p.present or not p.armed: return []
	var k: Dictionary=src.kind9
	if int(k.mask0)!=0 and (int(h.get("mask0",0))&int(k.mask0))==0: return []
	if int(k.mask2)!=0 and (int(h.get("mask2",0))&int(k.mask2))==0: return []
	if int(k.threshold)<int(h.get("after",255)): return []
	if int(h.get("special",0))==5 and not bool(h.get("special_admitted",false)): return []
	var queue:=_select(state,src,"prop",552,9,int(k.mask0),ctx)
	if queue.is_empty(): return []
	p.armed=false
	return _run(state,src,t,queue,ctx)

## Kind5 value1 on prop552 (producer unknown; supplied only).
static func record5(state: Dictionary, src: Dictionary, t: Dictionary, value: int, ctx: Dictionary) -> Array:
	return _dispatch(state,src,t,"prop",552,5,value,ctx)

## Commands other components run on prop552 (exit group10720 first-visibility, region4435/hit removals).
static func external_commands(state: Dictionary, src: Dictionary, t: Dictionary, commands: Array, ctx: Dictionary) -> Array:
	var effects: Array=[];var queue: Array=[]
	for raw in commands:
		var b: PackedByteArray=str(raw).hex_decode()
		if b.size()>=4 and b[1]==3 and (b[2]|(b[3]<<8))==552: _command(state,src,t,b,queue,effects,ctx)
	effects.append_array(_run(state,src,t,queue,ctx))
	return effects

static func advance(state: Dictionary, src: Dictionary, t: Dictionary, delta: float, ctx: Dictionary) -> Array:
	if not is_finite(delta) or delta<=0.0: return []
	var effects: Array=[]
	# Bacatta timers (1/60 s ticks).
	var total: float=float(state.ticks_fraction)+delta*float(src.tick_rate)
	var ticks:=int(floor(total));state.ticks_fraction=total-ticks
	if ticks>0:
		for row in src.timers:
			var key:=str(int(row.ordinal))
			var r: Dictionary=EventTimer.advance_with_rng(state.timers[key],ticks,state.rng,int(row.range[0]),int(row.range[1]),int(src.tick_rate))
			state.timers[key]=r.checkpoint;state.rng=int(r.rng)
			if r.fired: effects.append_array(_run(state,src,t,_select_group(state,src,"actor",61,int(row.group),ctx),ctx))
	# Sounds: a finished request raises kind8 with that request on Bacatta.
	var finished: Array=[]
	for s in state.sounds:
		s.elapsed=minf(float(s.elapsed)+delta,float(t.sounds[str(int(s.request))]))
		if float(s.elapsed)>=float(t.sounds[str(int(s.request))]): finished.append(s)
	for s in finished:
		state.sounds.erase(s)
		effects.append_array(_dispatch(state,src,t,"actor",61,8,int(s.request),ctx))
	# Load/start clips end with event0 (adapter); a repeating prop clip wraps and also reports event0.
	for owner in ["prop552","bacatta","guard60"]:
		var o: Dictionary=state[owner]
		if o.clip.is_empty(): continue
		var length: float=float(t.clips[_clip_key(owner,o.clip)])
		o.clip.elapsed=float(o.clip.elapsed)+delta
		if float(o.clip.elapsed)>=length:
			if owner=="prop552" and o.repeat: o.clip.elapsed=fmod(float(o.clip.elapsed),length)
			else: o.clip={}
			effects.append_array(_endpoint(state,src,t,owner,0,ctx))
	# Sprite pose requests cycle and report event3 at each cycle end (adapter).
	for owner in ["bacatta","guard60"]:
		var o: Dictionary=state[owner]
		if o.pose.is_empty(): continue
		var cycle: float=POSE7_FRAMES/POSE_FPS
		o.pose.elapsed=float(o.pose.elapsed)+delta
		if float(o.pose.elapsed)>=cycle:
			o.pose.elapsed=fmod(float(o.pose.elapsed),cycle)
			effects.append_array(_endpoint(state,src,t,owner,3,ctx))
	effects.append_array(_walk(state,src,t,delta,ctx))
	return effects

static func _endpoint(state: Dictionary, src: Dictionary, t: Dictionary, owner: String, event: int, ctx: Dictionary) -> Array:
	match owner:
		"prop552": return _dispatch(state,src,t,"prop",552,6,event,ctx) if state.prop552.present else []
		"bacatta": return _dispatch(state,src,t,"actor",61,6,event,ctx) if state.bacatta.present else []
		"guard60": return _dispatch(state,src,t,"actor",60,6,event,ctx) if _guard60(ctx) else []
	return []

static func _guard60(ctx: Dictionary) -> bool:
	var g: Dictionary=ctx.get("guard60",{})
	return bool(g.get("present",false)) and bool(g.get("alive",false))

## Behavior7 (goal7) path following along source path1; index advancement is the native-verified helper.
static func _walk(state: Dictionary, src: Dictionary, t: Dictionary, delta: float, ctx: Dictionary) -> Array:
	var b: Dictionary=state.bacatta
	if not b.present or int(b.goal)!=7 or (int(b.b5)&1)!=0: b.walking=false;return []
	var route: Dictionary=src.route
	var effects: Array=[]
	var budget:=WALK_SPEED*delta
	var guard:=0
	while budget>0.0 and guard<4:
		guard+=1
		var marker: Dictionary=route.points[int(PathControl.select_marker(route,int(b.path_index)).marker)-int(route.first)]
		var here:=Vector2(float(b.position[0]),float(b.position[1]));var goal:=Vector2(float(marker.x),float(marker.z))
		var distance:=here.distance_to(goal)
		b.walking=true
		if distance>ARRIVAL:
			var step:=minf(budget,distance-ARRIVAL*0.5)
			here+=(goal-here).normalized()*step;budget-=step
			b.position=[here.x,here.y]
			effects.append_array(_region(state,src,t,here,ctx))
			if b.goal!=7 or not b.present: break
			continue
		var next: Dictionary=PathControl.advance_index(route,int(b.path_index),0)
		b.path_index=int(next.index)
		if next.event22_requested:
			effects.append_array(_dispatch(state,src,t,"actor",61,6,22,ctx))
			break
	return effects

## Hostile Bacatta moves under the generic owner; its position still feeds the kind10 region records.
static func actor_moved(state: Dictionary, src: Dictionary, t: Dictionary, point: Vector2, ctx: Dictionary) -> Array:
	if not state.bacatta.present: return []
	state.bacatta.position=[point.x,point.y]
	return _region(state,src,t,point,ctx)

## Kind10: Bacatta's own movement into a source region (enter value0 event).
static func _region(state: Dictionary, src: Dictionary, t: Dictionary, point: Vector2, ctx: Dictionary) -> Array:
	var b: Dictionary=state.bacatta
	var inside:=-1
	for r in src.regions:
		var poly:=PackedVector2Array()
		for p in r.polygon: poly.append(Vector2(p[0],p[1]))
		if Geometry2D.is_point_in_polygon(point,poly): inside=int(r.region);break
	if inside==int(b.region): return []
	b.region=inside
	var effects: Array=[]
	for k in src.kind10:
		if int(k.region)==inside: effects.append_array(_run(state,src,t,_select_group(state,src,"actor",61,int(k.group),ctx),ctx))
	return effects

## ---- interpreter -------------------------------------------------------------------------
static func _owner_state(state: Dictionary, kind: String, owner: int) -> int:
	if kind=="prop" and owner==552: return int(state.prop552.state)
	if kind=="actor" and owner==61: return int(state.bacatta.state)
	if kind=="actor" and owner==60: return int(state.guard60.state)
	return 0

static func _operand(state: Dictionary, node: Dictionary, kind: String, owner: int, ctx: Dictionary) -> int:
	if node.has("immediate"): return int(node.immediate)
	if node.has("owner_state"): return _owner_state(state,kind,owner)
	if node.has("predicate"): return int(_test(state,node.expression,kind,owner,ctx))
	if node.has("shared"): return int(ctx.get("shared",{}).get(str(int(node.shared)),0))
	var id:=str(int(node.local))
	if state.locals.has(id): return int(state.locals[id])
	return int(ctx.get("locals",{}).get(id,0))

static func _test(state: Dictionary, p: Dictionary, kind: String, owner: int, ctx: Dictionary) -> bool:
	var l:=_operand(state,p.left,kind,owner,ctx);var r:=_operand(state,p.right,kind,owner,ctx)
	match str(p.op):
		"==": return l==r
		"!=": return l!=r
		"<=": return l<=r
		">=": return l>=r
		">": return l>r
		"<": return l<r
		"AND": return l!=0 and r!=0
		"OR": return l!=0 or r!=0
	return false

static func _select(state: Dictionary, src: Dictionary, kind: String, owner: int, record: int, value: int, ctx: Dictionary) -> Array:
	var queue: Array=[]
	for g in src.groups:
		if str(g.owner_kind)!=kind or int(g.owner)!=owner or int(g.record)!=record or (int(g.value)&255)!=(value&255): continue
		if g.predicate!=null and not _test(state,src.predicates[str(int(g.predicate))],kind,owner,ctx): continue
		queue.append(g)
	return queue

static func _select_group(state: Dictionary, src: Dictionary, kind: String, owner: int, group: int, ctx: Dictionary) -> Array:
	for g in src.groups:
		if int(g.group)==group and str(g.owner_kind)==kind and int(g.owner)==owner:
			if g.predicate!=null and not _test(state,src.predicates[str(int(g.predicate))],kind,owner,ctx): return []
			return [g]
	return []

static func _dispatch(state: Dictionary, src: Dictionary, t: Dictionary, kind: String, owner: int, record: int, value: int, ctx: Dictionary) -> Array:
	return _run(state,src,t,_select(state,src,kind,owner,record,value,ctx),ctx)

static func _run(state: Dictionary, src: Dictionary, t: Dictionary, queue: Array, ctx: Dictionary) -> Array:
	var effects: Array=[];var guard:=0
	while not queue.is_empty() and guard<64:
		guard+=1
		var g: Dictionary=queue.pop_front()
		effects.append({"type":"group","group":int(g.group)})
		for raw in g.commands: _command(state,src,t,str(raw).hex_decode(),queue,effects,ctx)
	return effects

static func _object(state: Dictionary, kind: int, target: int) -> Dictionary:
	if kind==3 and target==552: return state.prop552
	if kind==2 and target==61: return state.bacatta
	if kind==2 and target==60: return state.guard60
	return {}

## opcode8 property2 starts the whole selected clip; property9/10 start one VQA segment (15ED98 LIND index).
static func _start_clip(state: Dictionary, t: Dictionary, name: String, o: Dictionary, segment: int=-1) -> Dictionary:
	var clip:={"selector":int(o.selector),"segment":segment,"elapsed":0.0}
	if int(o.selector)<0 or not t.clips.has(_clip_key(name,clip)): return {}
	o.clip=clip
	return {"type":"clip","owner":name,"selector":int(o.selector),"segment":segment}

static func _command(state: Dictionary, src: Dictionary, t: Dictionary, b: PackedByteArray, queue: Array, effects: Array, ctx: Dictionary) -> void:
	var op:=b[0];var target:=b[2]|(b[3]<<8)
	var o:=_object(state,b[1],target)
	var name: String={552:"prop552",61:"bacatta",60:"guard60"}.get(target,"") if not o.is_empty() else ""
	var signed: int=b[5]-256 if b.size()>5 and b[5]>127 else (b[5] if b.size()>5 else 0)
	match op:
		198:
			if state.locals.has(str(b[4])): state.locals[str(b[4])]=b[5]
			else: effects.append({"type":"local","local":b[4],"value":b[5]})
		207:
			if state.locals.has(str(b[4])): state.locals[str(b[4])]=clampi(int(state.locals[str(b[4])])+signed,0,255)
			else: effects.append({"type":"local_add","local":b[4],"value":signed})
		206: effects.append({"type":"shared","index":b[4],"op":"add","value":signed})
		199: effects.append({"type":"shared","index":b[4],"op":"set","value":b[5]})
		16:
			if not o.is_empty(): o.state=b[4]
			elif b[1]==3 and target==4398: effects.append({"type":"exit_state","target":4398,"value":b[4]})
			else: effects.append({"type":"state","kind":b[1],"target":target,"value":b[4]})
		9:
			if b[4] in [2,3] and name in ["prop552","bacatta"]:
				var present:=b[4]==3
				if bool(o.present)!=present:
					o.present=present
					if not present:
						o.clip={}
						if name=="bacatta":
							o.pose={}
							if state.escort: state.escort=false;effects.append({"type":"escort","focus":false})
					effects.append({"type":"spawn" if present else "remove","owner":name})
					if name=="prop552": effects.append({"type":"prop_presence","present":present})
			elif b[4]==22 and name=="bacatta":
				if not state.escort: state.escort=true;effects.append({"type":"escort","focus":true})
			elif b[4]==21 and name=="guard60":
				if _guard60(ctx): queue.append_array(_select(state,src,"actor",60,6,20,ctx))
			elif b[4]==21 and b[1]==3 and target==4398:
				if not state.ending_requested: state.ending_requested=true;effects.append({"type":"exit_event20","source_group":"guard60"})
			else: effects.append({"type":"object_property","kind":b[1],"target":target,"property":b[4],"value":b[5]})
		13:
			if o.is_empty() or name=="prop552": effects.append({"type":"actor_command","target":target,"sub":b[4],"value":b[5]});return
			match b[4]:
				0:
					if name=="bacatta": o.goal=b[5]
				1:
					if name=="bacatta": o.action=b[5]
				4:
					if name=="guard60" and b[5]>=8 and t.clips.has("guard60:%d"%b[5]): o.selector=b[5];o.pose={}
					else: o.pose={"selector":b[5],"elapsed":0.0};effects.append({"type":"pose","owner":name,"selector":b[5]})
				6: o.b5=int(o.b5)|1
				7: o.b5=int(o.b5)&254
				10: o.b5=int(o.b5)&243 # A64F6: clear pending goal/action choice
				17:
					# A660D: A7544(actor,0), the ordinary zero-health outcome (event10/11, goal15, action16).
					if name=="bacatta": o.goal=15;o.action=16;o.walking=false
					effects.append({"type":"zero_health","owner":name,"mode":0})
				11: o.b5=int(o.b5)|4
				12: o.b5=int(o.b5)|8
				13: o.b5=(int(o.b5)&243)|12
				_: effects.append({"type":"actor_command","target":target,"sub":b[4],"value":b[5]})
		5:
			if not o.is_empty(): o.selector=b[4]
			else: effects.append({"type":"selector","kind":b[1],"target":target,"selector":b[4]})
		8:
			if o.is_empty(): effects.append({"type":"animation","kind":b[1],"target":target,"property":b[4],"raw":b.hex_encode()});return
			match b[4]:
				0: pass # load: the selected clip is loaded; start (2) begins it
				1: o.clip={}
				2:
					var started:=_start_clip(state,t,name,o)
					if not started.is_empty(): effects.append(started)
				7:
					if name=="prop552": o.repeat=b.decode_u16(6)!=0  # repeat count word (0x00ff loops, 0 plays once)
				9, 10:
					var started:=_start_clip(state,t,name,o,b.decode_u16(6))
					if not started.is_empty(): effects.append(started)
				_: effects.append({"type":"animation","owner":name,"property":b[4],"raw":b.hex_encode()})
		14:
			if b[1]==2 and target==61:
				var key:=str(b[6])
				if not state.timers.has(key): return
				var timer: Dictionary=state.timers[key]
				if b[4]==3 and (int(timer.flags)&1)!=0: timer.flags=int(timer.flags)&254
				elif b[4]==4: timer=EventTimer.stop(timer).checkpoint
				state.timers[key]=timer
			else: effects.append({"type":"timer","kind":b[1],"target":target,"operation":b[4],"raw":b.hex_encode()})
		20:
			var request:=b.decode_u16(4)
			if t.sounds.has(str(request)) and state.sounds.size()<MAX_SOUNDS: state.sounds.append({"request":request,"elapsed":0.0})
			effects.append({"type":"sound","owner":target,"request":request,"raw":b.hex_encode()})
		2:
			if b[1]==1 and b[4]==0x31 and state.escort:
				state.escort=false;effects.append({"type":"escort","focus":false})
			effects.append({"type":"player_property" if b[1]==1 else "object_property","kind":b[1],"target":target,"property":b[4],"value":b[5]})
		18:
			if b[1]==1: effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":b.hex_encode()})
		_: effects.append({"type":"presentation","raw":b.hex_encode()})
