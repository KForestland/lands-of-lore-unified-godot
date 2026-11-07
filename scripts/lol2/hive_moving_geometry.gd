extends RefCounted
## Rebuild exposed vertical intervals; same geometric policy as interior_spans.py.
## This is a Godot geometry adapter, not a native wall-builder port.
static func height(line: Array, t: float) -> float:
	return lerpf(float(line[0]),float(line[1]),t)
static func shifted(line: Array, amount: float) -> Array:
	return [float(line[0])+amount,float(line[1])+amount]
static func exposure(a_floor: Array, a_ceiling: Array, b_floor: Array, b_ceiling: Array) -> Array:
	var lines: Array=[a_floor,a_ceiling,b_floor,b_ceiling]
	var cuts: Array=[0.0,1.0]
	for i in range(4):
		for j in range(i+1,4):
			var d0: float=lines[i][0]-lines[j][0]
			var d1: float=lines[i][1]-lines[j][1]
			if d0*d1<0:
				var crossing:=d0/(d0-d1)
				if not cuts.has(crossing): cuts.append(crossing)
	cuts.sort()
	var result: Array=[]
	for i in range(cuts.size()-1):
		var left: float=cuts[i]
		var right: float=cuts[i+1]
		var mid: float=(left+right)*0.5
		var lower_top: Array=a_ceiling if height(a_ceiling,mid)<=height(b_floor,mid) else b_floor
		var upper_bottom: Array=a_floor if height(a_floor,mid)>=height(b_ceiling,mid) else b_ceiling
		for part in [["step",a_floor,lower_top],["upper",upper_bottom,a_ceiling]]:
			if height(part[2],mid)-height(part[1],mid)<=0.000000001: continue
			result.append({"kind":part[0],"t":[left,right],"low":[height(part[1],left),height(part[1],right)],"high":[height(part[2],left),height(part[2],right)]})
	return result
static func wall_uv(points: Array, style: Dictionary) -> Array:
	# Preserve the original review export's wall-record orientation/addressing.
	var raw: Array=style.raw
	var top: Array=[points[3],points[2],points[1],points[0]]
	var length: float=Vector2(top[0][0],top[0][2]).distance_to(Vector2(top[1][0],top[1][2]))
	var low: float=points[0][1]
	var high: float=low
	for point in points:
		low=minf(low,point[1])
		high=maxf(high,point[1])
	if length<=0 or high<=low: return []
	var mode: int=(int(raw[6])>>5)&3
	var pair: Array=[[0,1],[1,0],[3,2],[2,3]][mode]
	var origin: Array=top[pair[0]].duplicate()
	var end: Array=top[pair[1]]
	origin[1]=high if mode<2 else low
	var scale: float=[2.0,1.0,0.5,0.25][int(raw[7])&3]
	var addressing: int=8 if int(raw[6])&16 else 16 if int(raw[6])&8 else 0
	var w: float=style.width
	var h: float=style.height
	var dx: float=(end[0]-origin[0])/length
	var dz: float=(end[2]-origin[2])/length
	var uscale: float=scale if addressing else w/length
	var vscale: float=scale if addressing==8 else h/(high-low)
	var result: Array=[]
	for p in points:
		result.append([(((p[0]-origin[0])*dx+(p[2]-origin[2])*dz)*uscale+(raw[2] if addressing else 0))/w,((p[1]-origin[1])*(-1 if mode<2 else 1)*vscale+(raw[3] if addressing==8 else 0))/h])
	return result
static func faces(data: Dictionary, offsets: Dictionary) -> Array:
	var result: Array=[]
	for row in data.surfaces:
		var offset: float=offsets.get(str(row.kind)+str(int(row.region)),0.0)
		for original in row.faces:
			var face: Dictionary=original.duplicate(true)
			for point in face.points: point[1]+=offset
			result.append(face)
	for row in data.edges:
		var region:=str(int(row.region))
		var floor_line:=shifted(row.floor,offsets.get("floor"+region,0.0))
		var ceiling_line:=shifted(row.ceiling,offsets.get("ceiling"+region,0.0))
		var parts: Array=[]
		if row.neighbor==null:
			parts=[{"kind":"closed","t":[0.0,1.0],"low":floor_line,"high":ceiling_line}]
		else:
			var neighbor:=str(int(row.neighbor))
			parts=exposure(floor_line,ceiling_line,shifted(row.neighbor_floor,offsets.get("floor"+neighbor,0.0)),shifted(row.neighbor_ceiling,offsets.get("ceiling"+neighbor,0.0)))
		for part in parts:
			if maxf(part.high[0]-part.low[0],part.high[1]-part.low[1])<=0: continue
			var a:=Vector2(row.points[0][0],row.points[0][1]).lerp(Vector2(row.points[1][0],row.points[1][1]),part.t[0])
			var b:=Vector2(row.points[0][0],row.points[0][1]).lerp(Vector2(row.points[1][0],row.points[1][1]),part.t[1])
			var face: Dictionary={"region":row.region,"kind":"wall","points":[[a.x,part.low[0],a.y],[b.x,part.low[1],b.y],[b.x,part.high[1],b.y],[a.x,part.high[0],a.y]]}
			if row.styles.has(part.kind):
				var style: Dictionary=row.styles[part.kind]
				face.material=style.material
				face.uv=wall_uv(face.points,style)
			result.append(face)
	return result
