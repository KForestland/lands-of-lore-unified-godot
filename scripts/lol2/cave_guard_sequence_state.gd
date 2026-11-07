extends RefCounted
## Movie sequencer only. Host must consume source commands for doors/player/effects.
const Contact=preload("res://scripts/lol2/source_control_contact.gd")
const CALLBACKS=[4206,4240,4274,4308,4342,4376]
static func source() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_guard_sequence_source.json"))
static func initial() -> Dictionary:
	return {"version":1,"contact":Contact.initial(),"phase":"idle","selector":0,"elapsed":0.0,"control_state":0,"groups":[]}
static func duration(src: Dictionary, selector: int) -> float:
	var clip: Dictionary=src.clips[selector]
	# Presentation adapter shared with other VQA hosts: preserve the decoded voice tail.
	return ceilf(maxf(float(clip.count)/float(clip.fps),float(clip.audio_samples)/float(clip.audio_rate))*4096.0)/4096.0
static func receipts(selector: int, complete: bool) -> Array:
	var rows: Array=[9994,4184]
	for i in range(selector):rows.append(CALLBACKS[i])
	if complete:rows.append(4376)
	return rows
static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or s.get("version")!=1:return "Invalid guard sequence version."
	var error:=Contact.validate(s.get("contact"),src)
	if not error.is_empty():return error
	if s.get("phase") not in ["idle","armed","playing","complete"]:return "Invalid guard sequence phase."
	var n=s.get("selector")
	if not (n is int or n is float) or not is_finite(float(n)) or n!=floorf(float(n)) or n<0 or n>5:return "Invalid guard sequence selector."
	var t=s.get("elapsed")
	if not (t is int or t is float) or not is_finite(float(t)) or t<0 or t>duration(src,int(n)):return "Invalid guard sequence clock."
	if not s.get("groups") is Array:return "Invalid guard sequence receipts."
	if s.phase=="idle":
		if n!=0 or t!=0 or s.get("control_state")!=0 or not s.groups.is_empty():return "Idle guard sequence changed."
	elif s.phase=="armed":
		if n!=0 or t!=0 or s.get("control_state")!=1 or s.groups.size()!=1 or s.groups[0]!=9994:return "Armed guard sequence disagrees."
	else:
		if s.get("control_state")!=1:return "Guard sequence control mismatch."
		var expected:=receipts(int(n),s.phase=="complete")
		if s.groups.size()!=expected.size():return "Guard sequence receipt count mismatch."
		for i in range(expected.size()):
			if not (s.groups[i] is int or s.groups[i] is float) or s.groups[i]!=expected[i]:return "Guard sequence receipt mismatch."
		if s.phase=="playing" and t>=duration(src,int(n)):return "Running guard sequence ended."
		if s.phase=="complete" and (n!=5 or t!=duration(src,5)):return "Incomplete guard sequence marked complete."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true);r.version=1;r.contact=Contact.canonical(r.contact);r.selector=int(r.selector);r.elapsed=float(r.elapsed);r.control_state=int(r.control_state);r.groups=r.groups.map(func(n):return int(n));return r
static func group(s: Dictionary, src: Dictionary, id: int) -> Dictionary:
	s.groups.append(id)
	return {"group":id,"commands":src.groups[str(id)].commands.duplicate(true)}
static func enter(s: Dictionary, src: Dictionary, point: Vector2, foot: float, grounded: bool, form: int) -> Array:
	var hits:=Contact.update(s.contact,src,point,foot,grounded,form,{"104":s.control_state})
	if s.phase!="idle":return []
	for hit in hits:
		if hit.owner==104 and hit.value==4:
			s.phase="armed";s.control_state=1
			return [group(s,src,9994)]
	return []
## Source prop456 kind5/value0 starts only after accepted-render admission.
## Caller supplies visibility; this function does not infer it from plate entry.
static func rendered(s: Dictionary, src: Dictionary) -> Array:
	if s.phase!="armed":return []
	s.phase="playing"
	return [group(s,src,4184)]
static func advance(s: Dictionary, src: Dictionary, delta: float) -> Array:
	if s.phase!="playing" or not is_finite(delta) or delta<=0:return []
	var effects: Array=[]
	var remaining:=delta
	while s.phase=="playing" and remaining>0:
		var d:=duration(src,int(s.selector));var step:=minf(remaining,d-float(s.elapsed))
		s.elapsed=float(s.elapsed)+step;remaining-=step
		if s.elapsed>=d:
			effects.append(group(s,src,CALLBACKS[int(s.selector)]))
			if s.selector==5:s.phase="complete"
			else:s.selector+=1;s.elapsed=0.0
	return effects
