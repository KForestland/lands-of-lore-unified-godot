extends SceneTree
const S=preload("res://scripts/lol2/cave_guard_controls_state.gd")
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func run() -> void:
	var src:=S.source();var media:=S.media();var state:=S.initial()
	if not check(S.validate(state,src,media).is_empty(),"Initial guard controls"):return
	if not check(S.plate(state,src,109,4).is_empty(),"Human cannot admit109"):return
	S.plate(state,src,109,9)
	if not check(state.branch109=="beast" and state.prop1333==1 and state.actor39.goal==7 and state.actor39.action==1 and state.actor39.b5==0 and state.clips.prop533.resource==1912 and state.clips.prop533.playing,"Beast exact source branch"):return
	if not check(S.plate(state,src,109,7).is_empty(),"109 owner predicate one-shot"):return
	S.advance(state,src,media,0.5)
	var saved:=S.canonical(JSON.parse_string(JSON.stringify(state)))
	if not check(saved==state and S.validate(saved,src,media).is_empty(),"Partial movie exact roundtrip"):return
	S.advance(state,src,media,20)
	if not check(state.actor39.present and state.clips.prop533.done and 5174 in state.groups,"Original prop completion links39"):return
	S.hit39(state,src)
	if not check(state.actor39.b5==12,"Original guard39 hit decision request"):return
	S.entered39(state,src,746)
	if not check(state.actor39.removed and not state.actor39.present,"Original actor39 region746 removal"):return
	state=S.initial();S.plate(state,src,109,7)
	if not check(state.branch109=="lizard" and state.prop1333==0 and state.actor39.b5==12 and state.clips.prop533.resource==1913,"Lizard exact alternate movie/pending"):return
	state=S.initial();S.plate(state,src,114,4)
	if not check(S.input_locked(state) and state.actor52.selector==10 and state.clips.actor52.playing and not state.clips.control119.playing,"114 actor52 first movie"):return
	S.advance(state,src,media,20)
	if not check(14362 in state.groups and state.clips.actor52.done and state.clips.control119.playing and state.clips.control119.elapsed==0.0,"Actor52 event0 actually starts119, no skipped stage"):return
	S.advance(state,src,media,0.5);saved=S.canonical(JSON.parse_string(JSON.stringify(state)))
	if not check(saved==state,"Second stage partial exact roundtrip"):return
	S.advance(state,src,media,20)
	if not check(not S.input_locked(state) and not state.control119_present and state.actor52.b5==12 and 10332 in state.groups,"119 end releases and wakes52"):return
	var bad:=state.duplicate(true);bad.clips.actor52.elapsed=NAN
	if not check(not S.validate(bad,src,media).is_empty(),"Malformed clock rejects"):return
	bad=state.duplicate(true);bad.hidden39={"actor":{},"live":{}}
	if not check(not S.validate(bad,src,media).is_empty(),"Malformed retained actor rejects"):return
	for mutation in ["duplicate","completed_zero","running_terminal","wrong_branch","orphan119"]:
		bad=state.duplicate(true)
		match mutation:
			"duplicate":bad.groups.append(bad.groups[0])
			"completed_zero":bad.clips.actor52.elapsed=0.0
			"running_terminal":bad.clips.control119.done=false;bad.clips.control119.loaded=true;bad.clips.control119.playing=true
			"wrong_branch":bad.branch109="beast"
			"orphan119":bad.clips.actor52.done=false;bad.clips.actor52.elapsed=0.0
		if not check(not S.validate(bad,src,media).is_empty(),"Rejected unreachable tuple "+mutation):return
	print("PASS original109 beast/lizard branches, prop533 end links39, goal7/path0+hit and region746;114→actor52→119→wake/unlock, both partial roundtrips, malformed state")
	quit()
