extends SceneTree
## Cave eyes disk round trip: the saved checkpoint (State.quantized) must restore bit-exactly through
## Godot JSON and keep the live presentation frame, in every lifecycle phase, at every 10/23-frame
## boundary (just below, at, just above), across repeated round trips, without breaking phase/position/
## sound limits or stalling transitions; full runs with periodic reloads must still complete.
## Negative controls prove the checks catch the original defect (raw save: frame 2→3) and the
## released floor-only checkpoint (frame 3→2).
const State=preload("res://scripts/lol2/cave_eyes_state.gd")
var src: Dictionary
var failed:=false
var checked:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok

## Exactly the walkthrough save serialization.
func disk(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value,"  ",true,true))
func reload(state: Dictionary) -> Dictionary:
	return State.canonical(disk(State.quantized(state)))
## Neighbouring doubles (one ulp) through the IEEE bit pattern.
func adjacent(x: float, step: int) -> float:
	var b:=PackedByteArray();b.resize(8);b.encode_double(0,x)
	b.encode_s64(0,b.decode_s64(0)+step)
	return b.decode_double(0)
func state_for(phase: String, animation: float) -> Dictionary:
	var s:=State.initial(src);var last: int=src.path.points.size()-1
	s.phase=phase;s.animation=animation
	match phase:
		"starting": s.clock=animation
		"moving": s.index=3;var p: Array=src.path.points[2].position;s.position=[float(p[0])+0.3,float(p[1]),float(p[2])-0.7];s.sound_sample=12345.678
		"retiring": s.index=last;s.clock=1.2345678;var p: Array=src.path.points[last].position;s.position=[float(p[0]),float(p[1]),float(p[2])];s.sound_sample=float(src.sound.samples)-0.25
	return s

func run() -> void:
	src=State.source()
	# A. Every 1/4096 step in the legal animation range survives the save serialization bit-exactly.
	for k in range(int(ceil(23.0/15.0*4096.0))+1):
		var v:=float(k)/4096.0
		if not check(float(disk({"a":v}).a)==v,"Step %d/4096 does not round-trip"%k):return
	# ...and every saved position step over the eyes' world range and every sound sample count.
	var lo: float=INF;var hi: float=-INF
	for row in src.path.points+[{"position":src.position}]:
		for c in row.position: lo=minf(lo,float(c));hi=maxf(hi,float(c))
	for k in range(int(floor(lo*256.0))-256,int(ceil(hi*256.0))+256):
		var v:=float(k)/256.0
		if not check(float(disk({"a":v}).a)==v,"Position step %.8f does not round-trip"%v):return
	for n in range(int(src.sound.samples)+1):
		if n%7!=0 and n!=int(src.sound.samples): continue
		if not check(int(disk({"a":float(n)}).a)==n,"Sample %d does not round-trip"%n):return
	# Negative controls: the defects this test must catch.
	var acc:=0.0
	for i in 12: acc+=1.0/60.0
	if not check(State.frame(acc,"idle")==2 and State.frame(float(disk({"a":acc}).a),"idle")==3,"Original raw-save defect not reproduced"):return
	if not check(State.frame(0.2,"idle")==3 and State.frame(floorf(0.2*4096.0)/4096.0,"idle")==2,"Floor-only regression not reproduced"):return
	# B. Boundaries × phases × repeated round trips.
	var samples: Array=[acc]
	var running:=0.0
	for i in 140: running=fmod(running+1.0/60.0,23.0/15.0);samples.append(running)
	for f in range(24):
		var b:=float(f)/15.0
		samples.append_array([adjacent(b,-1),b,adjacent(b,1),b-1.0/8192,b+1.0/8192,b-1e-9,b+1e-9,b-1.0/4096,b+1.0/4096])
	for phase in ["idle","starting","moving","retiring"]:
		var limit:=23.0/15.0 if phase=="moving" else 10.0/15.0
		for v in samples:
			if not is_finite(v) or v<0 or v>=limit or (phase=="starting" and v>10.0/15.0-0.000001): continue
			var live:=state_for(phase,v)
			if not check(State.validate(live,src).is_empty(),"Fixture invalid: %s %.17f"%[phase,v]):return
			var current:=live
			for round in 3:
				var saved:=State.quantized(current)
				var restored:=reload(current)
				if not check(restored==saved,"Not bit-exact (%s %.17f round %d)"%[phase,v,round]):return
				if not check(State.validate(restored,src).is_empty(),"Invalid checkpoint (%s %.17f): %s"%[phase,v,State.validate(restored,src)]):return
				if not check(State.frame(restored.animation,phase)==State.frame(v,phase),"Frame changed %s %.17f: %d→%d"%[phase,v,State.frame(v,phase),State.frame(restored.animation,phase)]):return
				if not check(restored.phase==phase and restored.index==live.index and (absf(float(restored.animation)-v)<=1.0/4096 or (float(restored.animation)==0.0 and State.frame(v,phase)==0)) and absf(float(restored.clock)-float(live.clock))<=1.0/4096 and float(restored.sound_sample)<=float(live.sound_sample) and float(live.sound_sample)-float(restored.sound_sample)<1.0,"Phase/clock/sound drift %s %.17f"%[phase,v]):return
				current=restored
			checked+=1
	# C. Transition limits do not stall: starting just below its end, retiring just below 2 s.
	var start:=state_for("starting",10.0/15.0-0.000002)
	var rs:=reload(start);State.advance(rs,src,1.0/60.0)
	if not check(rs.phase=="moving","Starting stalled after reload"):return
	var retire:=state_for("retiring",0.5);retire.clock=adjacent(2.0,-1)
	var rr:=reload(retire);State.advance(rr,src,1.0/60.0)
	if not check(rr.phase=="removed","Retiring stalled after reload"):return
	# D. Full lifecycle with a disk reload every 7 updates matches an uninterrupted run.
	var plain:=State.initial(src);State.use(plain)
	var saved_run:=State.initial(src);State.use(saved_run)
	var steps:=[0,0]
	for which in 2:
		var s: Dictionary=plain if which==0 else saved_run
		for i in 20000:
			if s.phase=="removed": break
			if which==1 and i%7==0:
				var before:=State.frame(s.animation,s.phase)
				s=reload(s)
				if not check(State.frame(s.animation,s.phase)==before,"Lifecycle reload changed frame at step %d"%i):return
			State.advance(s,src,1.0/60.0);steps[which]+=1
		if not check(s.phase=="removed" and int(s.index)==src.path.points.size()-1,"Lifecycle did not complete (%d)"%which):return
	if not check(absi(steps[0]-steps[1])<=2,"Reloaded lifecycle length differs: %s"%[steps]):return
	# E. Existing saves: restore stays value-preserving (no quantization on load).
	var legacy:=state_for("moving",acc)
	if not check(State.canonical(legacy).animation==acc,"Restore of an existing save changed its value"):return
	if failed: return
	print("PASS cave eyes save round trip: %d steps exact; %d phase/boundary states × 3 JSON round trips bit-exact with unchanged live frame and legal phase/clock/sound; starting/retiring limits advance after reload; full lifecycle with reload every 7 updates completes in %d vs %d updates; original (2→3) and floor-only (3→2) defects reproduced as controls." % [int(ceil(23.0/15.0*4096.0))+1,checked,steps[1],steps[0]])
	quit()
