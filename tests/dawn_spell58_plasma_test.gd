extends SceneTree
## Spell 58 Plasma: executed request table (0x105A40, one-shot) and flight->impact mapping; lifecycle: Dawn selector 4
## flies at 200, arrival -> impact 5 -> one mask0x11/subtype0x3A/amount10 request from Dawn, impact animation end
## destroys; collision passes through the owner, damages only types 1/2/3/0x10, once.
const P=preload("res://scripts/lol2/dawn_spell58_plasma.gd")
func _initialize() -> void:
	var fx: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell7_58_requests_native.json"))
	var checked:=0
	for c in fx.cases:
		if c.function!="0x105a40": continue
		var s:=P.initial("owner","t",0,0);s.state=int(c.impact_state);s.request_latched=int(c.latched)!=0
		var got:=P.hit(s,"t" if c.has_target else null)
		var want: Array=c.requests
		if got.size()!=want.size(): push_error("Request count differs for state %s"%c.impact_state);quit(1);return
		for i in got.size():
			var g: Dictionary=got[i];var w: Dictionary=want[i]
			if [g.mask,g.signature,g.mode,g.subtype,g.amount]!=[int(w.mask),int(w.signature),int(w.mode),int(w.subtype),int(w.amount)] or (g.source==null)!=(int(w.owner)==0):
				push_error("Request differs for state %s: %s vs %s"%[c.impact_state,g,w]);quit(1);return
		checked+=1
	for k in fx.flight_to_impact:
		var want=fx.flight_to_impact[k]
		if (want==null and P.FLIGHT_TO_IMPACT.has(int(k))) or (want!=null and P.FLIGHT_TO_IMPACT.get(int(k))!=int(want)):
			push_error("Flight->impact differs at %s"%k);quit(1);return
	var U:=65536
	var s:=P.initial("dawn","player",0)
	var at:=[0,0];var reqs: Array=[];var ended:=false
	for tick in 100:
		var out:=P.step(s,{"position":at,"step":10*U,"positions":{"player":[95*U,0]},"animation_done":tick>20 and P.impact(s)})
		for e in out:
			if e.type=="move": at=[at[0]+10*U,0]
			if e.type=="request": reqs.append(e)
			if e.type=="destroy": ended=true
		if ended: break
	if not (reqs.size()==1 and reqs[0].mask==0x11 and reqs[0].subtype==0x3A and reqs[0].amount==10 and reqs[0].source=="dawn" and reqs[0].to=="player" and ended and int(s.state)==5):
		push_error("Plasma lifecycle differs: %s state=%s ended=%s"%[reqs,s.state,ended]);quit(1);return
	var c:=P.initial("dawn","x",0)
	if not (P.collide(c,{"touched":"dawn","touched_is_owner":true}).is_empty() and not c.hit):
		push_error("Owner pass-through differs");quit(1);return
	if not (P.collide(c,{"touched":"prop","touched_type":5}).is_empty() and c.hit and P.collide(c,{"touched":"y","touched_type":2}).is_empty()):
		push_error("Collision type filter / one-shot differs");quit(1);return
	var d:=P.initial("dawn","x",0);var r:=P.collide(d,{"touched":"guard","touched_type":2})
	if not (r.size()==1 and r[0].to=="guard" and r[0].amount==10):
		push_error("Collision hit differs: %s"%[r]);quit(1);return
	print("PASS dawn spell58 plasma: %d executed 0x105A40 cases + flight->impact table; selector4 arrival -> impact5 single 0x11/0x3A/10 request from Dawn then destroy; owner pass-through; type filter; one-shot."%checked)
	quit()
