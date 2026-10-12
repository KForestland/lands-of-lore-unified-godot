extends RefCounted
## Huline Jungle exit encounter (guards58-60, prop4398 endings) as pinned source command groups.
## Pure saved state + supplied triggers; the caller presents the returned effects.
## Source rules: ADDE0 evaluates handler predicates when queuing and runs queued groups FIFO;
## opcode13 B5 bit operations (A6348 table); opcode14 operation3/4 enable/disable a timer by
## ordinal; opcode207 saturating increment; timers tick at 60/s (countdown = range max x60).
## Opcode8: native VirtualAC result0 leaves the command queued (cave scenic guard audit). Each
## queued group keeps a saved cursor; an opcode8 command runs only when ctx.opcode8 (a supplied
## Callable) acknowledges it, otherwise the group waits there until resume(). Groups wait
## independently (same adapter as cave_scenic_guard_state.gd); native queue topology and the
## VirtualAC completion conditions are not claimed.
## Adapters: hit admission (kind9), defeat = event10, pose endpoint = event0, op9 property21
## dispatch timing. The prop552 kind5 guard spawn has no known producer: spawn_guards() is supplied.
const EventTimer = preload("res://scripts/lol2/hive_event_timer.gd")
const Values = preload("res://scripts/lol2/save_value_rules.gd")
const GUARDS := ["58","59","60"]
const BACATTA := "61"
const MAX_PENDING := 32

static func source(path: String="res://scripts/lol2/jungle_exit_encounter_source.json") -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func initial(src: Dictionary) -> Dictionary:
	var actors: Dictionary={}
	for row in src.actors:
		actors[str(int(row.actor))]={"present":bool(row.present),"state":0,"b5":0,"health":int(row.health),"pose":-1,"defeated":false}
	var timers: Dictionary={}
	for t in src.timers: timers["%d:%d"%[int(t.actor),int(t.ordinal)]]={"version":1,"flags":int(t.flags),"remaining":int(t.countdown)}
	var locals: Dictionary={}
	for id in src.owned_locals: locals[str(int(id))]=0
	return {"version":1,"locals":locals,"prop4398":0,"actors":actors,"timers":timers,"ticks_fraction":0.0,"rng":1,"ending":{},"pending":[]}

static func _integer(value: Variant, maximum: int) -> bool:
	return Values.integer(value,maximum)

static func group_row(src: Dictionary, group: int) -> Dictionary:
	for g in src.groups:
		if int(g.group)==group: return g
	return {}

static func validate(state: Variant, src: Dictionary) -> String:
	if not state is Dictionary or not _integer(state.get("version"),1) or int(state.version)!=1: return "Invalid exit encounter version."
	for key in ["locals","actors","timers","ending"]:
		if not state.get(key) is Dictionary: return "Invalid exit encounter "+key+"."
	if state.locals.size()!=src.owned_locals.size(): return "Invalid exit encounter locals."
	for id in src.owned_locals:
		if not _integer(state.locals.get(str(int(id))),255): return "Invalid exit encounter local."
	if not _integer(state.get("prop4398"),255) or not _integer(state.get("rng"),4294967295): return "Invalid exit encounter state."
	var fraction=state.get("ticks_fraction")
	if not (fraction is float or fraction is int) or not is_finite(float(fraction)) or float(fraction)<0 or float(fraction)>=1: return "Invalid exit encounter clock."
	if state.actors.size()!=src.actors.size(): return "Invalid exit encounter actors."
	for row in src.actors:
		var a=state.actors.get(str(int(row.actor)))
		if not a is Dictionary or not a.get("present") is bool or not a.get("defeated") is bool: return "Invalid exit encounter actor."
		if not _integer(a.get("state"),255) or not _integer(a.get("b5"),255) or not _integer(a.get("health"),int(row.health)): return "Invalid exit encounter actor."
		var pose=a.get("pose")
		if not (pose is int or pose is float) or (float(pose)!=-1 and not _integer(pose,255)): return "Invalid exit encounter pose."
		if a.defeated!=(int(a.health)==0): return "Exit encounter defeat disagrees with health."
	if state.timers.size()!=src.timers.size(): return "Invalid exit encounter timers."
	for t in src.timers:
		if EventTimer.restore(state.timers.get("%d:%d"%[int(t.actor),int(t.ordinal)])).has("error"): return "Invalid exit encounter timer."
	if not state.ending.is_empty():
		var known:=false
		for e in src.endings:
			if state.ending.size()==3 and state.ending.get("movie") is String and state.ending.movie==str(e.movie) and _integer(state.ending.get("movie_index"),255) and int(state.ending.movie_index)==int(e.movie_index) and _integer(state.ending.get("predicate"),255) and int(state.ending.predicate)==int(e.predicate): known=true
		if not known: return "Invalid exit encounter ending."
	# Packets staged before opcode8 cursors were modelled have no queue: nothing was waiting.
	var pending=state.get("pending",[])
	if not pending is Array or pending.size()>MAX_PENDING: return "Invalid exit encounter queue."
	for entry in pending:
		if not entry is Dictionary or entry.size()!=2 or not _integer(entry.get("group"),65535): return "Invalid exit encounter queued group."
		var g:=group_row(src,int(entry.group))
		if g.is_empty() or not _integer(entry.get("cursor"),g.commands.size()-1): return "Invalid exit encounter command cursor."
		# Only an unacknowledged opcode8 can hold a group between calls.
		if str(g.commands[int(entry.cursor)]).hex_decode()[0]!=8: return "Exit encounter cursor is not an opcode8 wait."
	return ""

static func canonical(state: Dictionary, src: Dictionary) -> Dictionary:
	var result: Dictionary=state.duplicate(true)
	for key in result.locals: result.locals[key]=int(result.locals[key])
	result.prop4398=int(result.prop4398);result.rng=int(result.rng);result.version=1;result.ticks_fraction=float(result.ticks_fraction)
	for id in result.actors:
		for key in ["state","b5","health","pose"]: result.actors[id][key]=int(result.actors[id][key])
	for key in result.timers: result.timers[key]=EventTimer.restore(result.timers[key]).checkpoint
	if not result.ending.is_empty():
		result.ending.movie_index=int(result.ending.movie_index);result.ending.predicate=int(result.ending.predicate)
	result.pending=result.get("pending",[]).map(func(e):return {"group":int(e.group),"cursor":int(e.cursor)})
	return result

## Guards fight once a source decision request is pending and unblocked (B5 0C set, bit01 clear).
static func fighting(state: Dictionary, id: String) -> bool:
	var a: Dictionary=state.actors[id]
	return a.present and not a.defeated and (int(a.b5)&12)!=0 and (int(a.b5)&1)==0

## Opcode8 commands each queued group is currently held at (empty when nothing waits).
static func waiting(state: Dictionary, src: Dictionary) -> Array:
	var result: Array=[]
	for entry in state.pending:
		result.append(_describe(group_row(src,int(entry.group)).commands[int(entry.cursor)],int(entry.group),int(entry.cursor)))
	return result

static func _describe(raw: String, group: int, cursor: int) -> Dictionary:
	var b:=raw.hex_decode()
	return {"group":group,"cursor":cursor,"op":b[0],"kind":b[1],"target":b[2]|(b[3]<<8),"argument":b[4],"raw":raw}

## ---- supplied triggers -------------------------------------------------------------------
## ctx: {"shared":{"13","14","18","47"}, "locals":{"41","49","51"}, "opcode8":Callable} supplied
## by the Jungle owner. opcode8(command) returns true once that wait may be passed.

static func enter_region(state: Dictionary, src: Dictionary, region: int, ctx: Dictionary) -> Array:
	return _dispatch(state,src,"region",region,2,0,ctx)

## Prop552 kind5 value0 (group10720). Producer unknown; callers must not invent one.
static func spawn_guards(state: Dictionary, src: Dictionary, ctx: Dictionary) -> Array:
	return _dispatch(state,src,"prop",552,5,0,ctx)

## Player hit on a guard: kind9 record (pred54), then damage; zero health dispatches event10.
static func damage(state: Dictionary, src: Dictionary, id: String, amount: int, ctx: Dictionary) -> Array:
	var a: Dictionary=state.actors.get(id,{})
	if a.is_empty() or not a.present or a.defeated or amount<=0: return []
	var effects: Array=_dispatch(state,src,"actor",int(id),9,0,ctx)
	a.health=maxi(0,int(a.health)-amount)
	effects.append({"type":"damage","actor":int(id),"health":int(a.health)})
	if int(a.health)==0:
		a.defeated=true
		effects.append_array(_dispatch(state,src,"actor",int(id),6,10,ctx))
	return effects

## Scripted pose (opcode8 0/2 after an opcode13 pose request) reached its endpoint: event0.
static func pose_finished(state: Dictionary, src: Dictionary, id: String, ctx: Dictionary) -> Array:
	var a: Dictionary=state.actors.get(id,{})
	if a.is_empty() or int(a.pose)<0: return []
	a.pose=-1
	return _dispatch(state,src,"actor",int(id),6,0,ctx)

## Retry every waiting opcode8 with the supplied acknowledgement.
static func resume(state: Dictionary, src: Dictionary, ctx: Dictionary) -> Array:
	return _drain(state,src,ctx,state.pending.size())

static func advance(state: Dictionary, src: Dictionary, delta: float, ctx: Dictionary) -> Array:
	if not is_finite(delta): return []
	var total: float=float(state.ticks_fraction)+maxf(delta,0.0)*float(src.tick_rate)
	var ticks:=int(floor(total));state.ticks_fraction=total-ticks
	var effects: Array=[]
	if ticks==0: return effects
	for t in src.timers:
		var key:="%d:%d"%[int(t.actor),int(t.ordinal)]
		var result: Dictionary=EventTimer.advance_with_rng(state.timers[key],ticks,state.rng,int(t.range[0]),int(t.range[1]),int(src.tick_rate))
		state.timers[key]=result.checkpoint;state.rng=int(result.rng)
		if result.fired: effects.append_array(_run_records(state,src,"actor",int(t.actor),2,null,ctx,int(t.group)))
	return effects

## ---- source interpreter ------------------------------------------------------------------

static func _owner_state(state: Dictionary, kind: String, owner: int) -> int:
	if kind=="actor" and state.actors.has(str(owner)): return int(state.actors[str(owner)].state)
	if kind=="prop" and owner==4398: return int(state.prop4398)
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

## ADDE0: every matching handler's predicate is evaluated now; groups then run FIFO.
static func _dispatch(state: Dictionary, src: Dictionary, kind: String, owner: int, record: int, value: Variant, ctx: Dictionary) -> Array:
	return _run_records(state,src,kind,owner,record,value,ctx,-1)

static func _enqueue(state: Dictionary, g: Dictionary, effects: Array) -> void:
	state.pending.append({"group":int(g.group),"cursor":0})
	effects.append({"type":"group","group":int(g.group)})

static func _run_records(state: Dictionary, src: Dictionary, kind: String, owner: int, record: int, value: Variant, ctx: Dictionary, only_group: int) -> Array:
	var effects: Array=[]
	var first:int=state.pending.size()
	for g in src.groups:
		if str(g.owner_kind)!=kind or int(g.owner)!=owner or int(g.record)!=record: continue
		if only_group>=0 and int(g.group)!=only_group: continue
		if value!=null and (int(g.value)&255)!=int(value): continue
		if g.predicate!=null and not _test(state,src.predicates[str(int(g.predicate))],kind,owner,ctx): continue
		_enqueue(state,g,effects)
	effects.append_array(_drain(state,src,ctx,first))
	return effects

## Runs each queued group from its cursor; an unacknowledged opcode8 holds only that group.
## Entries at index>=fresh were queued by this call (their first wait is reported once).
static func _drain(state: Dictionary, src: Dictionary, ctx: Dictionary, fresh: int) -> Array:
	var effects: Array=[]
	var i:=0
	while i<state.pending.size():
		var entry: Dictionary=state.pending[i]
		var commands: Array=group_row(src,int(entry.group)).commands
		var moved:=i>=fresh
		var blocked:=false
		while int(entry.cursor)<commands.size():
			if not _command(state,src,str(commands[int(entry.cursor)]).hex_decode(),effects,ctx):
				blocked=true
				if moved: effects.append({"type":"wait"}.merged(_describe(str(commands[int(entry.cursor)]),int(entry.group),int(entry.cursor))))
				break
			entry.cursor=int(entry.cursor)+1;moved=true
		if blocked: i+=1
		else:
			state.pending.remove_at(i)
			if fresh>i: fresh-=1
	return effects

static func _command(state: Dictionary, src: Dictionary, b: PackedByteArray, effects: Array, ctx: Dictionary) -> bool:
	var op:=b[0];var target:=b[2]|(b[3]<<8)
	var actor: Dictionary=state.actors.get(str(target),{}) if b[1]==2 else {}
	match op:
		8: # queue barrier: passes only when the supplied adapter acknowledges it
			var command:=_describe(b.hex_encode(),-1,-1)
			command.erase("group");command.erase("cursor")
			var acknowledge=ctx.get("opcode8")
			if not acknowledge is Callable or not acknowledge.is_valid() or acknowledge.call(command)!=true: return false
			effects.append({"type":"opcode8"}.merged(command))
		198: # local byte write
			if state.locals.has(str(b[4])): state.locals[str(b[4])]=b[5]
			else: effects.append({"type":"local","local":b[4],"value":b[5]})
		207: # local byte += n, saturating
			if state.locals.has(str(b[4])): state.locals[str(b[4])]=clampi(int(state.locals[str(b[4])])+(b[5] if b[5]<128 else b[5]-256),0,255)
		16: # owner state byte25
			if not actor.is_empty(): actor.state=b[4]
			elif b[1]==3 and target==4398: state.prop4398=b[4]
			else: effects.append({"type":"state","kind":b[1],"target":target,"value":b[4]})
		9:
			if b[4]==3 and not actor.is_empty():
				if not actor.present: actor.present=true;effects.append({"type":"spawn","actor":target})
			elif b[4]==2 and not actor.is_empty():
				if actor.present: actor.present=false;effects.append({"type":"remove","actor":target})
			elif b[4]==21: # event20 through ADDE0; predicates evaluated now, groups queued
				var kind: String={2:"actor",3:"prop"}.get(b[1],"")
				if kind!="" and (b[1]!=2 or bool(actor.get("present",false))):
					for g in src.groups:
						if str(g.owner_kind)==kind and int(g.owner)==target and int(g.record)==6 and (int(g.value)&255)==20 and (g.predicate==null or _test(state,src.predicates[str(int(g.predicate))],kind,target,ctx)): _enqueue(state,g,effects)
			else: effects.append({"type":"object","kind":b[1],"target":target,"property":b[4]})
		13: # A6348 subcommands
			if actor.is_empty(): return true
			match b[4]:
				4: actor.pose=b[5];effects.append({"type":"pose","actor":target,"selector":b[5]})
				6: actor.b5=int(actor.b5)|1
				7: actor.b5=int(actor.b5)&254
				10: actor.b5=int(actor.b5)&243
				11: actor.b5=int(actor.b5)|4
				12: actor.b5=int(actor.b5)|8
				13: actor.b5=(int(actor.b5)&243)|12
				_: effects.append({"type":"actor_command","actor":target,"sub":b[4],"value":b[5]})
		14: # timer operation3 enable / operation4 disable, ordinal byte6; argument byte5 reload
			var key:="%d:%d"%[target,b[6]]
			if not state.timers.has(key): return true
			var t: Dictionary=state.timers[key]
			if b[4]==3 and (int(t.flags)&1)!=0:
				t.flags=int(t.flags)&254
			elif b[4]==4: t=EventTimer.stop(t).checkpoint
			state.timers[key]=t
		21: # movie through opcode21; only the three staged prop4398 endings exist
			for e in src.endings:
				if int(e.movie_index)==b[4]: state.ending={"movie_index":b[4],"movie":str(e.movie),"predicate":int(e.predicate)}
			effects.append({"type":"movie","index":b[4],"movie":str(state.ending.get("movie",""))})
		18:
			if b[1]==1:
				var x:=b.decode_s16(4);var z:=b.decode_s16(6);var y:=b.decode_s16(8)
				effects.append({"type":"reposition","position":[x,y,-z],"raw":b.hex_encode()})
		_: effects.append({"type":"presentation","raw":b.hex_encode()})
	return true
