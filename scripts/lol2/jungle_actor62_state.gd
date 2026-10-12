extends RefCounted
## Source actor62 (L4_HJ, definition1 TIG_MAL): regions 1672/1698/1703 link him and raise event20 (low byte of 0x114);
## 29396 (state0) starts his four original lines, each opcode20 request finishing raises kind8 with that request
## (333→325→258→243, states 2..5); 29578 releases at state10 and sets action2 (op13 sub1, byte +0xAA). Event3 is the
## end of that action clip (Grok: ADDE0 push3 at 0xA56B3 when +0xAA==2) → 29610 at state10: state11, action1,
## B5|=0x0C, unblock. Event6 is never pushed by shipped data, so 29474/29494 are not produced.
## Adapters: the sound-finished clock is the decoded line duration; the action clip runs at 15 fps; both on a 1/4096 s grid.
const FPS:=15.0
const SOURCE="res://scripts/lol2/jungle_actor62_source.json"
const ACTOR:=62
static func source() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func initial(src: Dictionary) -> Dictionary:
	return {"version":1,"present":bool(src.actor.present),"owner_state":0,"selector":0,"action":0,"b5":0,"locals":{"44":0},"sound":{},"anim":{},"region":-1}
static func integer(v: Variant,lo: int,hi: int) -> bool:return (v is int or v is float) and is_finite(float(v)) and v==floor(float(v)) and v>=lo and v<=hi
static func reachable(src: Dictionary) -> Dictionary:
	var states: Array=[0];var selectors: Array=[0];var actions: Array=[0]
	for g in src.groups:
		for c in g.commands:
			var b: PackedByteArray=str(c).hex_decode()
			if b.size()<6 or b[1]!=2 or b.decode_u16(2)!=ACTOR:continue
			if b[0]==16 and int(b[4]) not in states:states.append(int(b[4]))
			if b[0]==13 and b[4]==4 and int(b[5]) not in selectors:selectors.append(int(b[5]))
			if b[0]==13 and b[4]==1 and int(b[5]) not in actions:actions.append(int(b[5]))
	return {"states":states,"selectors":selectors,"actions":actions}
static func validate(s: Variant,src: Dictionary) -> String:
	if not s is Dictionary or s.size()!=10 or not integer(s.get("version"),1,1):return "Invalid actor62 version."
	var reach:=reachable(src)
	if not integer(s.get("owner_state"),0,255) or int(s.owner_state) not in reach.states:return "Unreachable actor62 owner state."
	if not integer(s.get("selector"),0,255) or int(s.selector) not in reach.selectors:return "Unreachable actor62 pose."
	if not integer(s.get("action"),0,255) or int(s.action) not in reach.actions:return "Unreachable actor62 action."
	if not integer(s.get("b5"),0,255) or (int(s.b5)&~13)!=0:return "Unreachable actor62 B5."
	if not s.get("present") is bool or not integer(s.get("region"),-1,65535):return "Invalid actor62 actor."
	if not s.get("locals") is Dictionary or s.locals.size()!=1 or not integer(s.locals.get("44"),0,0):return "Invalid actor62 local44 (no shipped producer)."
	var sound=s.get("sound")
	if not sound is Dictionary:return "Invalid actor62 sound."
	if not sound.is_empty():
		if sound.size()!=2 or not integer(sound.get("request"),0,65535) or not src.voice.has(str(int(sound.request))):return "Invalid actor62 sound request."
		var elapsed=sound.get("elapsed")
		if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>=float(src.voice[str(int(sound.request))].duration):return "Invalid actor62 sound clock."
		# Each line is requested by exactly one state: 29396→333 (state2), 29512→325 (3), 29534→258 (4), 29556→243 (5).
		if int(s.owner_state)!={333:2,325:3,258:4,243:5}.get(int(sound.request),-1) or not s.present:return "actor62 line disagrees with his state."
	elif int(s.owner_state) in [2,3,4,5]:return "actor62 talk state without its line."
	var anim=s.get("anim")
	if not anim is Dictionary:return "Invalid actor62 action clip."
	if not anim.is_empty():
		if anim.size()!=2 or not integer(anim.get("action"),0,255) or int(anim.action)!=int(s.action) or not src.actions.has(str(int(anim.action))):return "Invalid actor62 action clip."
		var t=anim.get("elapsed")
		if not (t is float or t is int) or not is_finite(float(t)) or t<0 or t>=float(src.actions[str(int(anim.action))].frames)/FPS:return "Invalid actor62 action clock."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true)
	for k in ["version","owner_state","selector","action","b5","region"]:r[k]=int(r[k])
	r.locals={"44":int(r.locals["44"])}
	if not r.sound.is_empty():r.sound={"request":int(r.sound.request),"elapsed":float(r.sound.elapsed)}
	if not r.anim.is_empty():r.anim={"action":int(r.anim.action),"elapsed":float(r.anim.elapsed)}
	return r
static func predicate(s: Dictionary,p: Dictionary) -> bool:
	var a:=int(s.owner_state) if p.left.has("owner_state") else int(s.locals.get(str(int(p.left.get("local",-1))),0))
	var b:=int(p.right.immediate)
	match p.op:
		"==":return a==b
		"!=":return a!=b
	return false
static func select(s: Dictionary,src: Dictionary,kind: String,owner: int,event: int,value: int,full: bool=false) -> Array:
	var queue: Array=[]
	for g in src.groups:
		if g.owner_kind!=kind or int(g.owner)!=owner or int(g.event)!=event:continue
		if (int(g.value) if full else int(g.value)&255)!=(value if full else value&255):continue
		if g.predicate!=null and not predicate(s,src.predicates[str(int(g.predicate))]):continue
		queue.append(g)
	return queue
static func enter_region(s: Dictionary,src: Dictionary,region: int) -> Array:
	if int(s.region)==region:return []
	s.region=region
	return run(s,src,select(s,src,"region",region,2,0))
## Advance the requested line's clock; its end is the kind8 sound-finished event carrying the request.
static func advance(s: Dictionary,src: Dictionary,delta: float) -> Array:
	if not is_finite(delta) or delta<=0:return []
	var effects:=_advance_anim(s,src,delta)
	effects.append_array(_advance_sound(s,src,delta))
	return effects
## Action clip end: action2 raises event3 (Grok 0xA56B3); other actions have no source end event here.
static func _advance_anim(s: Dictionary,src: Dictionary,delta: float) -> Array:
	if s.anim.is_empty():return []
	s.anim.elapsed=snappedf(float(s.anim.elapsed)+delta,1.0/4096)
	if float(s.anim.elapsed)<float(src.actions[str(int(s.anim.action))].frames)/FPS:return []
	var action:=int(s.anim.action);s.anim={}
	return run(s,src,select(s,src,"actor",ACTOR,6,3)) if action==2 else []
static func _advance_sound(s: Dictionary,src: Dictionary,delta: float) -> Array:
	if s.sound.is_empty():return []
	var request:=int(s.sound.request)
	s.sound.elapsed=snappedf(float(s.sound.elapsed)+delta,1.0/4096)
	if float(s.sound.elapsed)<float(src.voice[str(request)].duration):return []
	s.sound={}
	return run(s,src,select(s,src,"actor",ACTOR,8,request,true))
static func run(s: Dictionary,src: Dictionary,queue: Array) -> Array:
	var effects: Array=[];var guard:=0
	while not queue.is_empty() and guard<32:
		guard+=1;var g: Dictionary=queue.pop_front();effects.append({"type":"group","group":int(g.group)})
		for raw in g.commands:
			var b: PackedByteArray=str(raw).hex_decode();var own:=b[1]==2 and b.decode_u16(2)==ACTOR
			match b[0]:
				9:
					if not own:effects.append({"type":"external","raw":raw});continue
					match b[4]:
						2:s.present=false;s.sound={}
						3:s.present=true
						21:queue.append_array(select(s,src,"actor",ACTOR,6,20))
						_:effects.append({"type":"actor_property","property":int(b[4]),"raw":raw})
				16:
					if own:s.owner_state=int(b[4])
					else:effects.append({"type":"external","raw":raw})
				20:
					if own and src.voice.has(str(b.decode_u16(4))):s.sound={"request":int(b.decode_u16(4)),"elapsed":0.0};effects.append({"type":"sound","request":int(b.decode_u16(4))})
					else:effects.append({"type":"external","raw":raw})
				13:
					if not own:effects.append({"type":"external","raw":raw});continue
					match b[4]:
						1:
							s.action=int(b[5])
							s.anim={"action":int(b[5]),"elapsed":0.0} if src.actions.has(str(int(b[5]))) else {}
						4:s.selector=int(b[5])
						7:s.b5=int(s.b5)&254
						13:s.b5=(int(s.b5)&243)|12
						_:effects.append({"type":"actor_command","sub":int(b[4]),"raw":raw})
				18:
					if b[1]==1:effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":raw})
					elif own:effects.append({"type":"actor_reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"heading":int(b.decode_u16(12)),"raw":raw})
					else:effects.append({"type":"external","raw":raw})
				2:
					if b[1]==1:effects.append({"type":"player_property","property":int(b[4]),"value":int(b[5]),"raw":raw})
					else:effects.append({"type":"actor_property","property":int(b[4]),"value":int(b[5]),"raw":raw})
				_:effects.append({"type":"external","raw":raw})
	return effects
