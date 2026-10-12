extends RefCounted
## Native1366EA integer bearing. Cast positioning uses the result shifted by8.
## Input is signed32 planar coordinates; differences preserve native wrap.
static func valid_point(point: Variant) -> bool:
	if not point is Array or point.size()!=2: return false
	for v in point:
		if not (v is int or v is float) or not is_finite(float(v)) or v!=floor(float(v)) or v < -2147483648 or v > 2147483647: return false
	return true

@warning_ignore("integer_division")
static func between(first: Variant, second: Variant) -> Dictionary:
	if not valid_point(first) or not valid_point(second): return {"error":"Invalid heading coordinates."}
	var x: int=(int(second[0])-int(first[0]))&0xffffffff
	var y: int=(int(second[1])-int(first[1]))&0xffffffff
	var quadrant:=0
	# JGE after SUB compares the signed endpoints, even if subtraction overflowed.
	if int(second[0])<int(first[0]): x=(-x)&0xffffffff;quadrant=0xc0
	if int(second[1])<int(first[1]): y=(-y)&0xffffffff;quadrant^=0x40
	var reflect: int=(quadrant&0x40)^0x40
	if y>=x:
		var old:=x;x=y;y=old;reflect^=0x40
	if y<256:
		while x>=256: x>>=1;y>>=1
	var ratio: int=0xffffffff if x==0 else (y<<8)/x
	var angle: int=ratio>>3
	if reflect!=0: reflect-=1;angle=-angle
	angle=(angle+reflect+quadrant)&255
	return {"byte":angle,"word":angle<<8}
