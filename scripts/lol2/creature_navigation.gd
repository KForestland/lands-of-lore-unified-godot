extends RefCounted
## Region-portal navigation for live creatures (modern adapter; no native pathfinder
## parity). Graph from tools/prepare_creature_nav.py: source region quads/floors and
## walkable portals with human clearance. Coordinates are source x/z (no origin).
const CELL:=256.0
var regions: Array=[]
var grid: Dictionary={}

func load_graph(path: String) -> String:
	if not FileAccess.file_exists(path): return "Missing creature navigation graph."
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version")!=1 or not data.get("regions") is Array: return "Invalid creature navigation graph."
	regions=data.regions
	grid.clear()
	for i in regions.size():
		var quad: Array=regions[i][0]
		if quad.size()!=4: continue
		var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
		for p in quad:
			lo=lo.min(Vector2(p[0],p[1]));hi=hi.max(Vector2(p[0],p[1]))
		for gx in range(floori(lo.x/CELL),floori(hi.x/CELL)+1):
			for gz in range(floori(lo.y/CELL),floori(hi.y/CELL)+1):
				var key:=Vector2i(gx,gz)
				if not grid.has(key): grid[key]=[]
				grid[key].append(i)
	return ""

## Region containing (x,z) whose floor is closest to y, or -1.
func region_at(point: Vector3) -> int:
	var key:=Vector2i(floori(point.x/CELL),floori(point.z/CELL))
	var best:=-1;var best_dy:=INF
	for i in grid.get(key,[]):
		var quad: Array=regions[i][0]
		var polygon:=PackedVector2Array([Vector2(quad[0][0],quad[0][1]),Vector2(quad[1][0],quad[1][1]),Vector2(quad[2][0],quad[2][1]),Vector2(quad[3][0],quad[3][1])])
		if not Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon): continue
		var dy:=absf(point.y-(float(regions[i][1])+float(regions[i][2]))/2.0)
		if dy<best_dy: best=i;best_dy=dy
	return best

## Next steering point (source x/z) from start toward goal, or null if unreachable
## within the expansion budget. Same region: the goal itself.
func next_point(start: Vector3, goal: Vector3, budget: int=600) -> Variant:
	var a:=region_at(start);var b:=region_at(goal)
	if a<0 or b<0: return null
	if a==b: return Vector2(goal.x,goal.z)
	var target:=Vector2(goal.x,goal.z)
	var open: Array=[[0.0,a]]
	var cost: Dictionary={a:0.0}
	var came: Dictionary={}
	var position: Dictionary={a:Vector2(start.x,start.z)}
	var expanded:=0
	while not open.is_empty() and expanded<budget:
		open.sort_custom(func(x,y):return x[0]<y[0])
		var current: int=open.pop_front()[1]
		expanded+=1
		if current==b: break
		for edge in regions[current][3]:
			var n:=int(edge[0]);var p:=Vector2(edge[1],edge[2])
			var c: float=cost[current]+position[current].distance_to(p)
			if not cost.has(n) or c<cost[n]:
				cost[n]=c;came[n]=[current,p];position[n]=p
				open.append([c+p.distance_to(target),n])
	if not came.has(b): return null
	var step:=b
	var point: Vector2=came[b][1]
	while came.has(step) and came[step][0]!=a:
		step=came[step][0];point=came[step][1]
	return point
