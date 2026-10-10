extends SceneTree
## Spell 7 chain bolt: target list equals the executed original 0x10ACC4 on every recorded case; hop limit draw range;
## lifecycle: arrival within 30 units hops (hit request on the reached target), chains, ends after the hop limit or an
## empty slot; overshoot hops; collision spends hops, skips sharp turns and leaves a visual hop.
const Chain=preload("res://scripts/lol2/dawn_spell7_chain.gd")
func _initialize() -> void:
	var fx: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell7_targets_native.json"))
	var n:=0
	for c in fx.cases:
		var cands: Array=c.candidates.map(func(x): return {"id":int(x.id),"position":[int(x.position[0]),int(x.position[1])],"valid":x.valid,"targetable":x.targetable,"type":int(x.type)})
		var own=null if c.owner==null else int(c.owner);var cur=null if c.current==null else int(c.current)
		var got:=Chain.targets(cands,own,cur,int(c.limit),[int(c.point[0]),int(c.point[1])])
		var want: Array=c.expected.targets.map(func(v): return null if v==null else int(v))
		if got.targets!=want or int(got.limit)!=int(c.expected.limit):
			push_error("Target list differs from native case %d: %s vs %s"%[n,got,c.expected]);quit(1);return
		n+=1
	if not (Chain.hop_limit(0)==3 and Chain.hop_limit(0x1F)==3 and Chain.hop_limit(0x20)==4 and Chain.hop_limit(0x5F)==5):
		push_error("Hop limit draw differs");quit(1);return
	# Lifecycle: three targets on a line east of the bolt, limit 3.
	var U:=65536
	var pos:={"a":[100*U,0],"b":[200*U,0],"c":[300*U,0]}
	var s:=Chain.initial("dawn",{"targets":["a","b","c"]+[null].duplicate().map(func(x):return null),"limit":3},0)
	s.list.resize(20)
	var at:=[0,0];var hits: Array=[];var cues:=0;var ended:=false
	for tick in 200:
		var out:=Chain.step(s,{"position":at,"step":8*U,"positions":pos})
		for e in out:
			if e.type=="spawn_hop" and e.target!=null: hits.append(e.target);assert(e.request==Chain.HOP_REQUEST)
			if e.type=="cue": cues+=1
			if e.type=="destroy": ended=true
			if e.type=="move": at=[at[0]+8*U,at[1]]   # supplied motion along +x
		if ended: break
	if not (hits==["a","b","c"] and cues==2 and ended):
		push_error("Chain lifecycle differs: hits=%s cues=%d ended=%s"%[hits,cues,ended]);quit(1);return
	# An empty slot ends the chain early.
	var e2:=Chain.initial("dawn",{"targets":["a",null],"limit":5},0);e2.list.resize(20)
	var out2:=Chain.step(e2,{"position":[99*U,0],"step":8*U,"positions":pos})
	if not (out2.filter(func(x): return x.type=="destroy").size()==1 and e2.ended):
		push_error("Empty-slot termination differs");quit(1);return
	# Collision (lists are cycle-filled to the limit): each candidate needing a turn > 0x4000 from the PREVIOUS candidate
	# spends a hop, as 0x10B2D8's loop does; a visual hop child is left at the collision point.
	var p3:={"a":[100*U,0],"back":[-100*U,0],"c":[300*U,0],"d":[250*U,0]}
	var c3:=Chain.initial("dawn",{"targets":["a","back","c","d","a"],"limit":5},0);c3.list.resize(20)
	Chain.collide(c3,{"position":[50*U,0],"positions":p3})
	var o3:=Chain.step(c3,{"position":[50*U,0],"step":8*U,"positions":p3})
	if not (c3.target=="a" and int(c3.hops)==4 and o3[0].type=="spawn_hop" and o3[0].target==null and not c3.ended):
		push_error("Collision skip differs: target=%s hops=%s fx=%s"%[c3.target,c3.hops,o3]);quit(1);return
	print("PASS dawn spell7 chain: %d executed 0x10ACC4 target cases equal; hop draw 3..5; arrival hops a->b->c with hit requests and end; empty slot ends; collision spends hops on sharp turns (vs previous candidate) and leaves a visual hop."%n)
	quit()
