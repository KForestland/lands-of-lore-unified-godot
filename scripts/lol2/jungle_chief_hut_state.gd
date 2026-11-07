extends RefCounted
## Source progression with explicit modern clocks. Shared Kelsrick locals6/8 stay with his owner.
const SOURCE := "res://assets/lol2/generated/jungle_chief_hut/source.json"
const FIRE_STEP := 2.0
const ROCK_TIME := 0.4
const MOVIE_TIME := 4.0
const ORDER := [572,568,564,563,569,567,562,571,566,570,565]
static func source() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func initial() -> Dictionary:
	return {"version":1,"locals":{"9":0,"10":0,"11":0,"14":0},"rock":0,"rock_elapsed":0.0,"fire_index":-1,"fire_elapsed":0.0,"phase":"idle","movie_elapsed":0.0,"seen_gate":-1,"inside":[],"floor_targets":{},"floor_heights":{},"floor_presets":{},"village_released":false}
static func integer(n: Variant, low: int, high: int) -> bool:
	return (n is int or n is float) and is_finite(float(n)) and n == floorf(float(n)) and n >= low and n <= high
static func validate(s: Variant) -> String:
	if not s is Dictionary or s.size()!=initial().size() or s.get("version")!=1: return "Invalid chief-hut state."
	if not s.get("locals") is Dictionary or s.locals.size()!=4: return "Invalid chief-hut locals."
	for k in ["9","10","11","14"]:
		if not integer(s.locals.get(k),0,1): return "Invalid chief-hut flag."
	if not integer(s.get("rock"),0,2) or not integer(s.get("fire_index"),-1,10) or not integer(s.get("seen_gate"),-1,1): return "Invalid chief-hut progress."
	for pair in [["rock_elapsed",ROCK_TIME],["fire_elapsed",FIRE_STEP],["movie_elapsed",MOVIE_TIME]]:
		var n = s.get(pair[0])
		if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>pair[1]: return "Invalid chief-hut clock."
	if s.get("phase") not in ["idle","fire","extinguished","movie","done"] or not s.get("village_released") is bool: return "Invalid chief-hut phase."
	if s.rock>0 and s.locals["10"]!=1: return "Oil rock lacks oil."
	if s.fire_index>=0 and s.locals["10"]!=1: return "Fire lacks oil."
	if s.phase=="idle" and s.fire_index!=-1: return "Idle puzzle has fire."
	if s.phase=="fire" and (s.fire_index<0 or s.rock!=2): return "Invalid spreading fire."
	if s.phase in ["movie","done"] and (s.fire_index<8 or s.locals["11"]!=1): return "Smoke-out lacks raised-water fire."
	if s.phase=="done" and s.movie_elapsed!=MOVIE_TIME: return "Incomplete hut movie."
	if s.phase not in ["movie","done"] and s.movie_elapsed!=0: return "Unstarted hut movie progressed."
	if s.village_released and s.phase!="done": return "Village released before smoke-out."
	if not s.get("inside") is Array or s.inside.size()>5: return "Invalid chief-hut region history."
	var seen: Array=[]
	for n in s.inside:
		if not integer(n,0,5000) or int(n) not in [2147,3568,3657,3792,2443] or int(n) in seen: return "Invalid chief-hut region."
		seen.append(int(n))
	for field in ["floor_targets","floor_heights","floor_presets"]:
		if not s.get(field) is Dictionary or s[field].size()>12: return "Invalid chief-hut surfaces."
		for k in s[field]:
			if k not in ["2341","2344","2612","2752","3740","3741","3742","3743","3744","3751","3752","4731"]: return "Unknown chief-hut surface."
			var n = s[field][k]
			if field=="floor_presets":
				if not integer(n,0,255) or int(n) not in [9,29,30,33]: return "Invalid pool preset."
			elif not (n is int or n is float) or not is_finite(float(n)) or n < -40 or n > 0: return "Invalid pool height."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r := s.duplicate(true)
	for k in ["version","rock","fire_index","seen_gate"]: r[k]=int(r[k])
	for k in r.locals: r.locals[k]=int(r.locals[k])
	for k in ["rock_elapsed","fire_elapsed","movie_elapsed"]: r[k]=float(r[k])
	for k in r.floor_presets: r.floor_presets[k]=int(r.floor_presets[k])
	for field in ["floor_heights","floor_targets"]:
		for k in r[field]: r[field][k]=float(r[field][k])
	r.inside=r.inside.map(func(n): return int(n))
	return r
static func group(src: Dictionary, id: int) -> Array:
	for r in src.records:
		if int(r.group)==id: return r.commands
	return []
static func run(s: Dictionary, src: Dictionary, id: int) -> Array:
	var effects: Array=[{"type":"group","group":id}]
	for row in group(src,id):
		var b: PackedByteArray=str(row.raw_hex).hex_decode()
		var target:=b.decode_u16(2)
		match b[0]:
			198:
				if s.locals.has(str(b[4])): s.locals[str(b[4])]=int(b[5])
				else: effects.append({"type":"kelsrick","group":id,"raw":row.raw_hex})
			196:
				var k:=str(target)
				s.floor_targets[k]=float(b.decode_s16(4))
				if not s.floor_heights.has(k):
					for face in src.floor_faces:
						if int(face.region)==target: s.floor_heights[k]=float(face.points[0][1]);break
			204:
				if b.decode_u16(4)==65535: s.floor_presets[str(target)]=int(b.decode_u16(6))
			16:
				if b[1]==3 and target==1486: s.rock=int(b[4])
				elif b[1]==2 and target==64: effects.append({"type":"kelsrick","group":id,"raw":row.raw_hex})
			5:
				# Selector only (its animation clock); rock owner state stays with op16 (g15764/g20500/g20778), which
				# Spark's source predicate p124 tests. Selector1 exists only in g15708 alongside local10=1.
				if b[1]==3 and target==1486: s.rock_elapsed=0.0
			206: effects.append({"type":"kelsrick","group":id,"raw":row.raw_hex})
			1: effects.append({"type":"gate","raw":row.raw_hex})
			18: effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)]})
			20: effects.append({"type":"sound","request":b.decode_u16(4)})
			_: effects.append({"type":"receipt","raw":row.raw_hex})
	return effects
static func raise_gate(s: Dictionary, src: Dictionary, talked: int) -> Array:
	if talked<=1 or s.locals["9"]==1: return []
	return run(s,src,21120)
static func observe_pool(s: Dictionary, src: Dictionary) -> Array:
	var gate:=int(s.locals["9"])
	if s.seen_gate==gate: return []
	s.seen_gate=gate
	if gate==0: return run(s,src,19760 if s.locals["10"]==0 else 19964)
	return run(s,src,20216 if s.locals["10"]==0 else 20500 if s.locals["14"]==0 else 20778)
static func strike(s: Dictionary, src: Dictionary) -> Array:
	if s.locals["10"]!=0 or s.phase!="idle": return []
	return run(s,src,15708)
static func ignite(s: Dictionary, src: Dictionary) -> Array:
	if s.locals["10"]!=1 or s.rock!=1 or s.rock_elapsed<ROCK_TIME or s.phase in ["fire","movie","done"]: return []
	s.phase="fire";s.fire_index=0;s.fire_elapsed=0.0
	return run(s,src,15736)
static func advance(s: Dictionary, src: Dictionary, delta: float) -> Array:
	if not is_finite(delta) or delta<=0: return []
	var effects: Array=[]
	if s.locals["10"]==1 and s.rock_elapsed<ROCK_TIME:
		var next: float=float(s.rock_elapsed)+delta
		s.rock_elapsed=ROCK_TIME if next>=ROCK_TIME else minf(ROCK_TIME,snappedf(next,1.0/65536))
		if s.rock_elapsed==ROCK_TIME and s.locals["11"]==1: effects.append_array(run(s,src,15764))
	for k in s.floor_targets:
		if s.floor_heights.has(k): s.floor_heights[k]=snappedf(move_toward(float(s.floor_heights[k]),float(s.floor_targets[k]),20.0*delta),1.0/65536)
	if s.phase=="fire":
		s.fire_elapsed=snappedf(float(s.fire_elapsed)+delta,1.0/65536)
		while s.fire_elapsed>=FIRE_STEP and s.phase=="fire":
			s.fire_elapsed-=FIRE_STEP;s.fire_index+=1
			if s.fire_index==8 and s.locals["11"]==1:
				s.phase="movie";s.fire_elapsed=0.0
				effects.append_array(run(s,src,14260))
			elif s.fire_index==8: effects.append_array(run(s,src,14242))
			elif s.fire_index==10: s.phase="extinguished";s.fire_elapsed=0.0
	elif s.phase=="movie":
		s.movie_elapsed=minf(MOVIE_TIME,snappedf(float(s.movie_elapsed)+delta,1.0/65536))
		if s.movie_elapsed==MOVIE_TIME:
			s.phase="done"
			effects.append_array(run(s,src,14086))
	return effects
static func village_entry(s: Dictionary, src: Dictionary, alert: int) -> Array:
	if s.phase!="done" or s.village_released or alert!=0: return []
	s.village_released=true
	return run(s,src,4442)
