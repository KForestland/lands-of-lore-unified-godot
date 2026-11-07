extends RefCounted
## Original support109/114 and movie completion consumers. Geometry/voices live outside.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Contact=preload("res://scripts/lol2/source_control_contact.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const GUARDS="res://scripts/lol2/cave_guard_population_source.json"
const SOURCE="res://scripts/lol2/cave_guard_controls_source.json"
const MEDIA="res://assets/lol2/generated/cave_guard_controls/media.json"
static func source() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func media() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
static func initial() -> Dictionary:
	var clips: Dictionary={}
	for pair in [["prop533",1912],["actor52",1914],["control119",1916]]:clips[pair[0]]={"resource":pair[1],"elapsed":0.0,"loaded":false,"playing":false,"done":false}
	return {"version":1,"contact":Contact.initial(),"controls":{"109":0,"114":0},"prop1333":0,"branch109":"none","actor39":{"present":false,"goal":14,"action":9,"b5":0,"path_index":0,"region":-1,"removed":false},"actor52":{"selector":-1,"b5":0},"clips":clips,"control119_present":true,"events":{},"groups":[],"hidden39":{},"walk_clock":0.0}
static func integer(value: Variant, maximum: int, minimum: int=0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=minimum and value<=maximum
static func validate(s: Variant, src: Dictionary, m: Dictionary) -> String:
	if not s is Dictionary or not integer(s.get("version"),1,1):return "Invalid guard controls version."
	var error:=Contact.validate(s.get("contact"),src)
	if not error.is_empty():return error
	if not s.get("controls") is Dictionary or s.controls.size()!=2:return "Invalid guard control states."
	for id in ["109","114"]:
		if not integer(s.controls.get(id),1):return "Invalid guard control state."
	if not integer(s.get("prop1333"),1) or s.get("branch109") not in ["none","beast","lizard"]:return "Invalid guard109 branch."
	if not s.get("actor39") is Dictionary or not s.get("actor52") is Dictionary:return "Invalid guard actors."
	for key in ["present","removed"]:
		if not s.actor39.get(key) is bool:return "Invalid guard39 presence."
	for key in ["goal","action","b5"]:
		if not integer(s.actor39.get(key),255):return "Invalid guard39 source state."
	if not integer(s.actor39.get("path_index"),8,-8) or not integer(s.actor39.get("region"),65535,-1):return "Invalid guard39 route."
	if not integer(s.actor52.get("selector"),10,-1) or not integer(s.actor52.get("b5"),255):return "Invalid guard52 state."
	if not s.get("control119_present") is bool or not s.get("clips") is Dictionary or s.clips.size()!=3:return "Invalid guard movie state."
	for owner in ["prop533","actor52","control119"]:
		var c=s.clips.get(owner)
		if not c is Dictionary or not integer(c.get("resource"),1916):return "Invalid guard movie."
		var resource:=int(c.resource)
		if resource not in ([1912,1913] if owner=="prop533" else [1914] if owner=="actor52" else [1916]):return "Wrong guard movie owner."
		for key in ["loaded","playing","done"]:
			if not c.get(key) is bool:return "Invalid guard movie latch."
		var t=c.get("elapsed")
		if not (t is int or t is float) or not is_finite(float(t)) or t<0 or t>duration(m,resource):return "Invalid guard movie clock."
		if c.playing:
			if not c.loaded or c.done or t>=duration(m,resource):return "Inconsistent running guard movie."
		elif c.done:
			if c.loaded or t!=duration(m,resource):return "Inconsistent completed guard movie."
		elif c.loaded or t!=0:return "Inconsistent idle guard movie."
	if not s.get("events") is Dictionary or not s.get("groups") is Array or s.groups.size()>8:return "Invalid guard source receipts."
	for id in s.events:
		if id not in ["prop533","actor39"] or not integer(s.events[id],1,1):return "Invalid guard event mode."
	var seen: Array=[]
	for group in s.groups:
		if not integer(group,20000) or not src.groups.has(str(int(group))):return "Invalid guard command group."
		if int(group) in seen:return "Repeated guard command receipt."
		seen.append(int(group))
	if not s.get("hidden39") is Dictionary:return "Invalid retained guard39."
	if not s.hidden39.is_empty():
		if not s.hidden39.has("actor") or not s.hidden39.has("live"):return "Incomplete retained guard39."
		var population_source:=Generic.source(GUARDS);var packet:=Generic.initial(population_source)
		packet.actors["39"]=s.hidden39.actor;packet.live["39"]=s.hidden39.live
		error=Generic.validate(packet,population_source)
		if not error.is_empty():return error
	var clock=s.get("walk_clock")
	if not (clock is int or clock is float) or not is_finite(float(clock)) or clock<0 or clock>=1.75:return "Invalid guard walk clock."
	var prop: Dictionary=s.clips.prop533;var first: Dictionary=s.clips.actor52;var second: Dictionary=s.clips.control119
	if s.branch109=="none":
		if prop.playing or prop.done or int(prop.resource)!=1912 or s.prop1333!=0 or s.actor39.goal!=14 or s.actor39.action!=9 or s.actor39.b5!=0 or s.actor39.removed or s.actor39.path_index!=0 or s.walk_clock!=0 or not s.hidden39.is_empty():return "Inactive guard109 branch changed."
		if 10114 in seen or 10198 in seen or 5174 in seen or 14312 in seen or 14306 in seen:return "Inactive guard109 has receipts."
	else:
		var path_branch: bool=s.branch109=="beast"
		if s.controls["109"]!=1 or not (prop.playing or prop.done) or int(prop.resource)!=(1912 if path_branch else 1913) or s.prop1333!=(1 if path_branch else 0):return "Guard109 branch disagrees with movie."
		if (10114 if path_branch else 10198) not in seen or (10198 if path_branch else 10114) in seen:return "Guard109 receipt disagrees."
		if s.actor39.goal!=(7 if path_branch else 14) or s.actor39.action!=(1 if path_branch else 9) or int(s.actor39.b5) not in ([0,12] if path_branch else [12]):return "Guard109 actor outcome disagrees."
		if prop.playing and (s.actor39.present or s.actor39.removed or s.actor39.path_index!=0 or s.walk_clock!=0):return "Guard39 active before prop completion."
		if bool(prop.done)!=(5174 in seen):return "Guard39 completion receipt disagrees."
		if prop.done and bool(s.actor39.present)==bool(s.actor39.removed):return "Guard39 completed presence disagrees."
		if bool(s.actor39.removed)!=(14306 in seen) or (s.actor39.removed and s.actor39.region!=746):return "Guard39 removal disagrees."
		if 14312 in seen and (not prop.done or s.actor39.b5!=12):return "Guard39 hit receipt disagrees."
	if s.branch109=="none":
		if not s.events.is_empty():return "Inactive guard109 has event modes."
	else:
		if not s.events.has("prop533") or s.events.has("actor39")!=bool(prop.done) or s.events.size()!=(2 if prop.done else 1):return "Guard109 event modes disagree."
	if first.playing or first.done:
		if s.controls["114"]!=1 or s.actor52.selector!=10 or 10266 not in seen:return "Guard114 first stage disagrees."
	else:
		if s.actor52.selector!=-1 or s.actor52.b5!=0 or 10266 in seen:return "Inactive guard114 actor changed."
	if bool(first.done)!=(14362 in seen) or bool(second.playing or second.done)!=bool(first.done):return "Guard114 second stage has no producer."
	if bool(second.done)!=(10332 in seen) or bool(s.control119_present)==bool(second.done) or s.actor52.b5!=(12 if second.done else 0):return "Guard119 terminal outcome disagrees."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true);r.version=1;r.contact=Contact.canonical(r.contact);r.prop1333=int(r.prop1333);r.walk_clock=float(r.walk_clock)
	for id in r.controls:r.controls[id]=int(r.controls[id])
	for key in ["goal","action","b5","path_index","region"]:r.actor39[key]=int(r.actor39[key])
	for key in ["selector","b5"]:r.actor52[key]=int(r.actor52[key])
	for c in r.clips.values():c.resource=int(c.resource);c.elapsed=float(c.elapsed)
	for id in r.events:r.events[id]=int(r.events[id])
	if not r.hidden39.is_empty():
		var src:=Generic.source(GUARDS);var p:=Generic.initial(src);p.actors["39"]=r.hidden39.actor;p.live["39"]=r.hidden39.live;p=Generic.canonical(p,src)
		r.hidden39={"actor":p.actors["39"],"live":p.live["39"]}
	r.groups=r.groups.map(func(n):return int(n));return r
static func duration(m: Dictionary, resource: int) -> float:return ceilf(float(m.clips[str(resource)].duration)*4096)/4096
static func input_locked(s: Dictionary) -> bool:return s.clips.actor52.playing or s.clips.control119.playing
static func plate(s: Dictionary, src: Dictionary, control: int, value: int) -> Array:
	if not s.controls.has(str(control)) or int(s.controls[str(control)])!=0:return []
	var group:=10114 if control==109 and value==9 else 10198 if control==109 and value==7 else 10266 if control==114 and value==4 else -1
	return run(s,src,group) if group>=0 else []
static func hit39(s: Dictionary,src: Dictionary) -> Array:return run(s,src,14312) if s.actor39.present and s.branch109!="none" else []
static func entered39(s: Dictionary,src: Dictionary,region: int) -> Array:
	if region==int(s.actor39.region):return []
	s.actor39.region=region
	return run(s,src,14306) if region==746 and s.actor39.present else []
static func advance(s: Dictionary,src: Dictionary,m: Dictionary,delta: float) -> Array:
	if not is_finite(delta) or delta<=0:return []
	var playing: Array=[]
	for key in s.clips:
		if s.clips[key].playing:playing.append(key)
	var effects: Array=[]
	for owner in playing:
		var c: Dictionary=s.clips[owner];c.elapsed=minf(duration(m,int(c.resource)),snappedf(float(c.elapsed)+delta,1.0/4096))
		if c.elapsed>=duration(m,int(c.resource)):
			c.playing=false;c.done=true
			effects.append_array(run(s,src,{"prop533":5174,"actor52":14362,"control119":10332}[owner]))
	return effects
static func run(s: Dictionary,src: Dictionary,group: int) -> Array:
	if group in s.groups:return []
	s.groups.append(group)
	if group==10114:s.branch109="beast"
	elif group==10198:s.branch109="lizard"
	var effects: Array=[]
	for row in src.groups[str(group)].commands:
		var b:=str(row.raw_hex).hex_decode();var op:=int(b[0]);var kind:=int(b[1]);var id:=int(b.decode_u16(2));var arg:=int(b[4])
		var owner: String=("actor" if kind==2 else "prop" if kind==3 else "control")+str(id)
		match op:
			16:
				if kind==16 and s.controls.has(str(id)):s.controls[str(id)]=arg
				elif kind==3 and id==1333:s.prop1333=arg
			9:
				if owner=="actor39":s.actor39.present=arg==3;s.actor39.removed=arg==2 and group==14306
				elif owner=="control119":s.control119_present=arg==3
				if owner=="actor39":effects.append({"type":"presence","actor":39,"present":arg==3})
			6:s.events[owner]=arg
			5:
				if owner=="prop533":s.clips.prop533.resource=1912+arg
			8:
				var clip: Dictionary=s.clips[owner]
				if arg==0:clip.loaded=true
				elif arg==1:clip.loaded=false;clip.playing=false
				elif arg==2:clip.playing=true;clip.elapsed=0.0;clip.done=false
			13:
				var actor: Dictionary=s.actor39 if id==39 else s.actor52
				match arg:
					0:actor.goal=int(b[5])
					1:actor.action=int(b[5])
					4:actor.selector=int(b[5])
					6:actor.b5=int(actor.b5)|1
					7:actor.b5=int(actor.b5)&254
					13:actor.b5=(int(actor.b5)&243)|12
				if arg==13:effects.append({"type":"pending","actor":id})
			18:effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":row.raw_hex})
			2:effects.append({"type":"player_property","property":arg,"value":int(b[5])})
	return effects
