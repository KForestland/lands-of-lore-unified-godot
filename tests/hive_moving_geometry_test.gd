extends SceneTree
const Geometry=preload("res://scripts/lol2/hive_moving_geometry.gd")
const Sequence=preload("res://scripts/lol2/hive_boulder_sequence.gd")
func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_boulders/boulders.json"))
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_review/hive.json"))
	var expected: Array=[]
	for face in original.faces:
		if face.kind=="wall" and face.region in data.wall_regions:
			# The old export contains two degenerate zero-height walls at801.
			var low: float=face.points[0][1]
			var high: float=low
			for p in face.points:
				low=minf(low,p[1])
				high=maxf(high,p[1])
			if high>low: expected.append(face)
		for row in data.surfaces:
			if face.kind==row.kind and face.region==row.region: expected.append(face)
	var actual:=Geometry.faces(data,Sequence.offsets(Sequence.initial()))
	assert(actual.size()==expected.size(),"Initial geometry count differs: %d vs %d" % [actual.size(),expected.size()])
	for face in expected:
		var found:=false
		for candidate in actual:
			if candidate.region!=face.region or candidate.kind!=face.kind: continue
			var same:=true
			for i in range(4):
				for axis in range(3):
					if not is_equal_approx(candidate.points[i][axis],face.points[i][axis]): same=false
			if not same: continue
			assert(candidate.get("material","")==face.get("material",""),"Initial material differs")
			if face.has("uv"):
				for i in range(4):
					for axis in range(2): assert(is_equal_approx(candidate.uv[i][axis],face.uv[i][axis]),"Initial wall UV differs")
			found=true
			break
		assert(found,"Missing initial original face "+str(face))
	var state:=Sequence.initial()
	Sequence.begin(state)
	Sequence.advance(state,100)
	var finished:=Geometry.faces(data,Sequence.offsets(state))
	var west_lower:=false
	var east_upper:=false
	for face in finished:
		if face.region!=1216 or face.kind!="wall": continue
		if face.points[0][0]==-2384 and face.points[1][0]==-2384 and face.points[0][1]==-1700 and face.points[2][1]==-1387: west_lower=true
		if face.points[0][0]==-2075 and face.points[1][0]==-2075 and face.points[0][1]==-1600: east_upper=true
	assert(west_lower and east_upper,"Moving floor must expose lower west wall and open east exit")
	# A crossing slope must split at the crossing, not cover the open half-edge.
	var slope:=Geometry.exposure([0,0],[10,10],[-5,5],[10,10])
	assert(slope.size()==1 and slope[0].t==[0.5,1.0] and slope[0].high==[0.0,5.0])
	print("PASS moving geometry reproduces initial source faces/materials/UVs and rebuilds sloped portal intervals, emerging west wall and relative east exit")
	quit()
