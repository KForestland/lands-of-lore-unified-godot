extends RefCounted
## Huline Jungle pre-exit L4WW conversation: prop554 (template83) and actors 0/66, from pinned source groups.
## Pure saved state; the controller supplies producers (regions, sighting, hits) and presents effects.
## Clip clocks are owned here, as in jungle_bacatta_state.gd, and every playback carries a generation:
## starts, stops, selector changes, link/removal and restore() bump it, so an end callback is admitted only
## for the current mode, selector AND generation (stale media callbacks after restore/relink are ignored).
## Native endpoints: kind3 value N = object frame stepper end of selector N (F24FE/F256B); kind6 value0 =
## clip end (prop552 convention); kind9 = AE2C8 mode4 (after <= threshold, one-shot per record).
## Native bindings (static, LOLG.DAT): object opcode table 0x5C878 → opcode5 B5970 → class vtable 0xA848
## +B0 F2944 stores the selector, sets the frame count from the template (F1F94-1) and frame 0 via F2814;
## the frame stepper F24FE then raises kind3 value=selector at the end of that frame run. Template 83 has one
## resource per selector, so the run is one frame: modelled as a one-frame "frames" track started by every
## opcode5. Opcode8 (vtable +AC F22B4 → B43EC table 0x5B39C): 0 load, 1 unload, 2 start, 7 repeat; the
## started clip ends with kind6 value0. Opcode2 (B5BAC) properties 5/6 are player properties on the object:
## 5 → DD5DC(player, object, value) focus, 6 → clears the player focus slot 0x22621 when it holds the object.
const SOURCE := "res://scripts/lol2/jungle_exit_woman_source.json"
const MEDIA := "res://assets/lol2/generated/jungle_exit_woman_media/media.json"
const MAX_ELAPSED := 120.0
const MAX_GENERATION := 0x7fffffff

static func source(path: String=SOURCE) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

## Per-selector durations from the staged media: sounded clip = max(frames/fps, voice); frames = frames/fps.
static func timing(path: String=MEDIA) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var m=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not m is Dictionary: return {}
	var t:={"clip":{},"frames":{}}
	# Frame run = template resources per selector (one) at the clip's frame rate.
	for s in m.clips:
		t.clip[s]=float(m.clips[s].duration);t.frames[s]=1.0/float(m.clips[s].fps)
	return t

static func initial(src: Dictionary) -> Dictionary:
	var actors := {}
	for id in src.actors: actors[id] = {"present":false}
	return {"version":1,"local1":0,"hold":false,"latches":[],
		"prop":{"present":bool(src.prop.present),"state":0,"selector":0,"repeat":false,"generation":0,"clip":{},"frames":{}},"actors":actors,"focus":false}

static func _int(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=0 and value<=maximum

static func validate(state: Variant, src: Dictionary) -> String:
	if not state is Dictionary or not _int(state.get("version"),1) or state.version!=1: return "Invalid exit conversation version."
	if not _int(state.get("local1"),255) or not state.get("hold") is bool: return "Invalid exit conversation locals."
	var p = state.get("prop")
	if not p is Dictionary or not p.get("present") is bool or not _int(p.get("state"),255) or not _int(p.get("selector"),16) or not p.get("repeat") is bool or not _int(p.get("generation"),MAX_GENERATION) or not p.get("clip") is Dictionary or not p.get("frames") is Dictionary:
		return "Invalid exit conversation prop."
	for track in ["clip","frames"]:
		var c: Dictionary=p[track]
		if c.is_empty(): continue
		if not p.present or c.size()!=3 or not _int(c.get("selector"),16) or not _int(c.get("generation"),MAX_GENERATION) or int(c.generation)>int(p.generation):
			return "Invalid exit conversation playback."
		var e = c.get("elapsed")
		if not (e is int or e is float) or not is_finite(float(e)) or e<0 or e>MAX_ELAPSED: return "Invalid exit conversation playback clock."
	if not p.frames.is_empty() and int(p.frames.selector)!=int(p.selector): return "Invalid exit conversation frame animation."
	if not state.get("focus",false) is bool: return "Invalid exit conversation focus."
	var a = state.get("actors")
	if not a is Dictionary or a.size()!=src.actors.size(): return "Invalid exit conversation actors."
	for id in src.actors:
		if not a.get(id) is Dictionary or not a[id].get("present") is bool: return "Invalid exit conversation actor."
	var l = state.get("latches")
	if not l is Array or l.size()>2: return "Invalid exit conversation latches."
	var groups := {}
	for r in src.records:
		if int(r.kind)==9: groups[int(r.group)]=true
	for g in l:
		if not _int(g,65535) or not groups.has(int(g)) or l.count(g)!=1: return "Invalid exit conversation latch."
	return ""

static func canonical(state: Dictionary) -> Dictionary:
	var result: Dictionary=state.duplicate(true)
	result.version=1;result.local1=int(result.local1)
	for key in ["state","selector","generation"]: result.prop[key]=int(result.prop[key])
	for track in ["clip","frames"]:
		if result.prop[track].is_empty(): continue
		for key in ["selector","generation"]: result.prop[track][key]=int(result.prop[track][key])
		result.prop[track].elapsed=float(result.prop[track].elapsed)
	result.latches=result.latches.map(func(g): return int(g))
	return result

## After a restore every in-flight media callback belongs to an older presentation. The owner passes its
## runtime high-water mark (highest generation it ever issued, kept outside the saved state): the restored
## playback resumes above it, so callbacks from any earlier presentation, including an earlier load of the
## same packet or its later playback, can never match. Required, so no caller can omit it.
static func restored(state: Dictionary, high_water: int) -> void:
	state.prop.generation=maxi(int(state.prop.generation),mini(high_water,MAX_GENERATION))
	_bump(state)

## A new generation for the whole object: running tracks are retagged, older callbacks become stale.
## No wrap: MAX_GENERATION is an exhausted sentinel that no callback is admitted for (fails closed).
static func _bump(state: Dictionary) -> void:
	state.prop.generation=mini(int(state.prop.generation)+1,MAX_GENERATION)
	for track in ["clip","frames"]:
		if not state.prop[track].is_empty(): state.prop[track].generation=state.prop.generation

static func playing(state: Dictionary) -> bool: return not state.prop.clip.is_empty() or not state.prop.frames.is_empty()

static func enter_region(state: Dictionary, src: Dictionary, region: int, ctx: Dictionary={}) -> Array:
	return _dispatch(state,src,"region",region,2,0,ctx)
static func sighted(state: Dictionary, src: Dictionary, ctx: Dictionary={}) -> Array:
	return _dispatch(state,src,"prop",int(src.prop.id),5,0,ctx) if state.prop.present else []
static func actor_event(state: Dictionary, src: Dictionary, actor: int, kind: int, value: int, ctx: Dictionary={}) -> Array:
	if not state.actors.has(str(actor)) or not state.actors[str(actor)].present: return []
	return _dispatch(state,src,"actor",actor,kind,value,ctx)

## Guarded endpoints: only the current frame animation of this selector and generation (kind3 value N).
static func selector_finished(state: Dictionary, src: Dictionary, selector: int, generation: int, ctx: Dictionary={}) -> Array:
	var c: Dictionary=state.prop.frames
	if not state.prop.present or c.is_empty() or generation>=MAX_GENERATION or int(c.generation)!=generation or int(c.selector)!=selector or int(state.prop.selector)!=selector: return []
	state.prop.frames={};_bump(state)
	return _dispatch(state,src,"prop",int(src.prop.id),3,selector,ctx)

## Guarded endpoint: only the current sounded clip of this selector and generation (kind6 value0).
static func clip_ended(state: Dictionary, src: Dictionary, selector: int, generation: int, ctx: Dictionary={}) -> Array:
	var c: Dictionary=state.prop.clip
	if not state.prop.present or c.is_empty() or generation>=MAX_GENERATION or int(c.generation)!=generation or int(c.selector)!=selector: return []
	if state.prop.repeat: c.elapsed=0.0
	else: state.prop.clip={};_bump(state)
	return _dispatch(state,src,"prop",int(src.prop.id),6,0,ctx)

## Clip clocks. A wrapped repeating clip reports kind6 value0 at each loop end, like prop552.
static func advance(state: Dictionary, src: Dictionary, t: Dictionary, delta: float, ctx: Dictionary={}) -> Array:
	if not is_finite(delta) or delta<=0.0 or t.is_empty(): return []
	var effects: Array=[]
	var f: Dictionary=state.prop.frames
	if not f.is_empty():
		f.elapsed=minf(float(f.elapsed)+delta,MAX_ELAPSED)
		if float(f.elapsed)>=float(t.frames.get(str(int(f.selector)),0.0)): effects.append_array(selector_finished(state,src,int(f.selector),int(f.generation),ctx))
	var c: Dictionary=state.prop.clip
	if not c.is_empty():
		var length: float=float(t.clip.get(str(int(c.selector)),0.0))
		c.elapsed=minf(float(c.elapsed)+delta,MAX_ELAPSED)
		if float(c.elapsed)>=length:
			var overshoot: float=float(c.elapsed)-length
			effects.append_array(clip_ended(state,src,int(c.selector),int(c.generation),ctx))
			if state.prop.repeat and not state.prop.clip.is_empty() and state.prop.clip.generation==c.generation: state.prop.clip.elapsed=minf(overshoot,length)
	return effects

## Hit on prop554 (h: {"mask0","mask2","after"}): AE2C8 mode4, admitted when after <= threshold; each
## qualifying record is one-shot. The context special byte (0x23331==5) path is not modelled here.
static func hit(state: Dictionary, src: Dictionary, h: Dictionary, ctx: Dictionary={}) -> Array:
	if not state.prop.present: return []
	var k: Dictionary=src.kind9
	if int(k.mask0)!=0 and (int(h.get("mask0",0))&int(k.mask0))==0: return []
	if int(k.mask2)!=0 and (int(h.get("mask2",0))&int(k.mask2))==0: return []
	if int(k.threshold)<int(h.get("after",255)): return []
	var queue: Array=[]
	for r in _records(state,src,"prop",int(src.prop.id),9,0,ctx):
		if int(r.group) in state.latches: continue
		if bool(k.one_shot): state.latches.append(int(r.group))
		queue.append(r)
	return _run(state,src,queue,ctx)

## Commands other owners run on prop554/local1 (exit guard spawn group10720: local1=5, prop554 removed).
static func external_commands(state: Dictionary, src: Dictionary, commands: Array, ctx: Dictionary={}) -> Array:
	var effects: Array=[]
	for raw in commands:
		var b: PackedByteArray=str(raw).hex_decode()
		# JSON loads the local list as floats; compare as integers.
		if (b[0]==198 and src.locals.any(func(v): return int(v)==b[4])) or (b.size()>=4 and b[1]==3 and (b[2]|(b[3]<<8))==int(src.prop.id)): _command(state,src,b,effects)
	return effects

static func _dispatch(state: Dictionary, src: Dictionary, kind: String, owner: int, record: int, value: int, ctx: Dictionary) -> Array:
	return _run(state,src,_records(state,src,kind,owner,record,value,ctx),ctx)

## ADDE0 rule: predicates are evaluated when the event is queued; groups then run FIFO.
static func _records(state: Dictionary, src: Dictionary, kind: String, owner: int, record: int, value: int, ctx: Dictionary) -> Array:
	var result: Array=[]
	for r in src.records:
		if str(r.owner_kind)!=kind or int(r.owner)!=owner or int(r.kind)!=record or int(r.value)!=value: continue
		if r.predicate!=null and not _test(state,src.predicates[str(int(r.predicate))],kind,owner,src,ctx): continue
		result.append(r)
	return result

static func _run(state: Dictionary, src: Dictionary, queue: Array, ctx: Dictionary) -> Array:
	var effects: Array=[]
	for r in queue:
		effects.append({"type":"group","owner_kind":r.owner_kind,"owner":int(r.owner),"group":int(r.group)})
		for raw in r.commands: _command(state,src,str(raw).hex_decode(),effects)
	return effects

static func _operand(state: Dictionary, node: Dictionary, kind: String, owner: int, src: Dictionary, ctx: Dictionary) -> int:
	if node.has("immediate"): return int(node.immediate)
	if node.has("local"): return int(state.local1) if int(node.local)==1 else int(ctx.get("locals",{}).get(str(int(node.local)),0))
	if node.has("owner_state"):
		if kind=="prop": return int(state.prop.state)
		return 0
	if node.has("expression"): return 1 if _test(state,node.expression,kind,owner,src,ctx) else 0
	return 0

static func _test(state: Dictionary, p: Dictionary, kind: String, owner: int, src: Dictionary, ctx: Dictionary) -> bool:
	var a:=_operand(state,p.left,kind,owner,src,ctx);var b:=_operand(state,p.right,kind,owner,src,ctx)
	match str(p.op):
		"==": return a==b
		"!=": return a!=b
		"<=": return a<=b
		">=": return a>=b
		">": return a>b
		"<": return a<b
		"AND": return a!=0 and b!=0
		"OR": return a!=0 or b!=0
	return false

static func _start(state: Dictionary, src: Dictionary, track: String, effects: Array) -> void:
	_bump(state)
	state.prop[track]={"selector":int(state.prop.selector),"elapsed":0.0,"generation":int(state.prop.generation)}
	effects.append({"type":"clip_start" if track=="clip" else "frames_start","selector":int(state.prop.selector),"generation":int(state.prop.generation),
		"repeat":bool(state.prop.repeat),"vqa":src.prop.selectors.get(str(int(state.prop.selector)),"")})

static func _command(state: Dictionary, src: Dictionary, b: PackedByteArray, effects: Array) -> void:
	var op:=b[0];var target:=b[2]|(b[3]<<8)
	var on_prop:=b[1]==3 and target==int(src.prop.id)
	var actor:=str(target) if b[1]==2 and state.actors.has(str(target)) else ""
	match op:
		198:
			if b[4]==1: state.local1=b[5]
			else: effects.append({"type":"local","local":b[4],"value":b[5]})
		16:
			if on_prop: state.prop.state=b[4]
			else: effects.append({"type":"state","kind":b[1],"target":target,"value":b[4]})
		5:
			if not on_prop: return
			state.prop.selector=b[4]
			effects.append({"type":"selector","selector":b[4],"vqa":src.prop.selectors.get(str(b[4]),"")})
			# F2944: a new selector restarts the object's frame run from frame 0.
			_start(state,src,"frames",effects)
		8:
			if not on_prop: effects.append({"type":"animation","kind":b[1],"target":target,"raw":b.hex_encode()});return
			match b[4]:
				0: pass # load the selected clip; property2 starts it
				1:
					if not state.prop.clip.is_empty(): state.prop.clip={};_bump(state)
					effects.append({"type":"clip_stop"})
				2: _start(state,src,"clip",effects)
				7: state.prop.repeat=b.decode_u16(6)!=0
				_: effects.append({"type":"animation","owner":"prop","property":b[4],"raw":b.hex_encode()})
		9:
			if on_prop and b[4] in [2,3]:
				var present:=b[4]==3
				if bool(state.prop.present)!=present:
					state.prop.present=present
					state.prop.clip={};state.prop.frames={};_bump(state)
					effects.append({"type":"prop_presence","present":present})
			elif actor!="" and b[4] in [2,3]:
				var present:=b[4]==3
				if bool(state.actors[actor].present)!=present:
					state.actors[actor].present=present
					effects.append({"type":"spawn" if present else "remove","actor":int(actor),"definition":int(src.actors[actor].definition),"position":src.actors[actor].position})
			else: effects.append({"type":"object_property","kind":b[1],"target":target,"property":b[4],"value":b[5]})
		2:
			if b[1]==1 and b[4] in [0x26,0x27]:
				state.hold=b[4]==0x26
				effects.append({"type":"hold","held":state.hold})
			elif on_prop and b[4] in [5,6]:
				state.focus=b[4]==5 and b[5]!=0
				effects.append({"type":"focus","held":state.focus})
			else: effects.append({"type":"player_property" if b[1]==1 else "object_property","kind":b[1],"target":target,"property":b[4],"value":b[5]})
		18:
			if b[1]==1: effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":b.hex_encode()})
		_: effects.append({"type":"presentation","raw":b.hex_encode()})
