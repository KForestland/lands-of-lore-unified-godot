extends SceneTree
const Geometry=preload("res://scripts/lol2/hive_moving_geometry.gd")
const Controller=preload("res://scripts/lol2/hive_boulder_surfaces.gd")
func _initialize() -> void:
	assert(Controller.replaces({"region":1217.0,"kind":"floor"}))
	assert(Controller.replaces({"region":795.0,"kind":"wall"}))
	assert(not Controller.replaces({"region":795.0,"kind":"floor"}))
	assert(not Controller.replaces({"region":1216.0,"kind":"ceiling"}))
	assert(Geometry.exposure([0,0],[10,10],[0,0],[10,10]).is_empty())
	assert(Geometry.exposure([0,0],[10,10],[-5,-5],[15,15]).is_empty())
	var lower:=Geometry.exposure([0,0],[10,10],[4,4],[10,10])
	assert(lower.size()==1 and lower[0].kind=="step" and lower[0].low==[0.0,0.0] and lower[0].high==[4.0,4.0])
	var upper:=Geometry.exposure([0,0],[10,10],[0,0],[6,6])
	assert(upper.size()==1 and upper[0].kind=="upper" and upper[0].low==[6.0,6.0] and upper[0].high==[10.0,10.0])
	var crossing:=Geometry.exposure([0,0],[10,10],[-5,5],[15,5])
	assert(crossing.size()==2)
	for part in crossing: assert(part.t==[0.5,1.0])
	var above:=Geometry.exposure([0,0],[10,10],[15,15],[20,20])
	assert(above.size()==1 and above[0].low==[0.0,0.0] and above[0].high==[10.0,10.0])
	var below:=Geometry.exposure([0,0],[10,10],[-10,-10],[-5,-5])
	assert(below.size()==1 and below[0].low==[0.0,0.0] and below[0].high==[10.0,10.0])
	var quad: Array=[[0,0,0],[20,0,0],[20,10,0],[0,10,0]]
	var style: Dictionary={"raw":[0,0,0,0,0,0,0,1],"width":32,"height":16}
	assert(Geometry.wall_uv(quad,style)==[[0.0,1.0],[1.0,1.0],[1.0,0.0],[0.0,0.0]])
	style.raw[6]=16 # World-unit addressing retains scale as the wall grows.
	assert(Geometry.wall_uv(quad,style)==[[0.0,0.625],[0.625,0.625],[0.625,0.0],[0.0,0.0]])
	var stretched:=quad.duplicate(true)
	stretched[2][1]=20
	stretched[3][1]=20
	assert(Geometry.wall_uv(stretched,style)[0]==[0.0,1.25])
	print("PASS portable exposed intervals, crossing slopes, disjoint sectors and wall UV addressing")
	quit()
