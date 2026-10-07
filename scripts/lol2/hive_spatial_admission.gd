extends RefCounted
## Native136594 Euclidean /1365C4 approximate distances and B1F54 vertical gate.
const Geometry = preload("res://scripts/lol2/hive_condition_geometry.gd")
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func _signed(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= -2147483648 and value <= 2147483647
static func _i32(value: int) -> int:
	var unsigned := value&0xffffffff
	return unsigned-4294967296 if unsigned >= 2147483648 else unsigned

static func horizontal_approximate(points: Variant) -> Dictionary:
	if not points is Array or points.size() != 4: return {"error":"Four fixed-point coordinates required."}
	for value in points:
		if not _signed(value): return {"error":"Invalid fixed-point coordinate."}
	var dx := _i32(int(points[0])-int(points[2]))
	var dy := _i32(int(points[1])-int(points[3]))
	if dx < 0: dx = _i32(-dx)
	if dy < 0: dy = _i32(-dy)
	# Signed compare, then logical shift: preserve native INT_MIN behavior.
	return {"distance":_i32(maxi(dx,dy)+((mini(dx,dy)&0xffffffff)>>1))}

static func bearing(points: Variant) -> Dictionary:
	if not points is Array or points.size()!=4: return {"error":"Four bearing coordinates required."}
	for value in points:
		if not _signed(value): return {"error":"Invalid bearing coordinate."}
	var dx := _i32(int(points[2])-int(points[0]))
	var dy := _i32(int(points[3])-int(points[1]))
	var quadrant := 0
	# JGE follows SUB, retaining signed-overflow semantics of endpoint comparison.
	if int(points[2])<int(points[0]): dx=_i32(-dx);quadrant=192
	if int(points[3])<int(points[1]): dy=_i32(-dy);quadrant^=64
	dx&=0xffffffff;dy&=0xffffffff
	var reflection := (quadrant&64)^64
	if dy>=dx:
		var swap := dx;dx=dy;dy=swap
		reflection^=64
	if dy<256:
		while dx>=256: dx>>=1;dy>>=1
	var ratio := 0xffffffff if dx==0 else (dy*256/dx)
	ratio>>=3
	if reflection!=0: reflection-=1;ratio=-ratio
	return {"bearing":(ratio+reflection+quadrant)&255}

static func horizontal_euclidean(points: Variant, control_word: Variant) -> Dictionary:
	if not points is Array or points.size() != 4: return {"error":"Four fixed-point coordinates required."}
	for value in points:
		if not _signed(value): return {"error":"Invalid fixed-point coordinate."}
	if not Numbers._integer(control_word,65535): return {"error":"Explicit x87 control word required."}
	var delta := [_i32(int(points[0])-int(points[2])),_i32(int(points[1])-int(points[3]))]
	# Reduce arbitrary fixed endpoints to the already verified origin-distance
	# helper, preserving signed32 subtraction before the squared distance.
	if int(control_word) == 0x127f:
		return Geometry.distance_startup(delta,[0,0])
	if int(control_word) in [0x37f,0x77f,0xb7f,0xf7f]:
		return Geometry.distance9(delta,[0,0],(int(control_word)>>10)&3)
	return {"error":"Unsupported x87 precision or rounding configuration."}

static func vertical(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid vertical context."}
	if not _signed(context.get("z")) or not _signed(context.get("target_z")): return {"error":"Invalid fixed-point elevation."}
	if not Numbers._integer(context.get("height"),255) or not Numbers._integer(context.get("target_height"),255): return {"error":"Invalid virtual height."}
	var upper := _i32(int(context.z)+(int(context.height)<<16)+0x400000)
	var lower := _i32(int(context.z)-0x400000)
	var target_top := _i32(int(context.target_z)+(int(context.target_height)<<16))
	var classification := 0 if int(context.target_z)>upper else (4 if target_top>lower else (3 if target_top==lower else 1))
	return {"classification":classification}

static func sword_distance_gate(distance: Variant, player_form: Variant) -> Dictionary:
	# Native88EC6: caller supplies136594 result. Vertical/target checks follow.
	if not _signed(distance) and not Numbers._integer(distance,0xffffffff): return {"error":"Invalid sword distance result."}
	if not Numbers._integer(player_form,255): return {"error":"Invalid source player form."}
	var limit := (64 if int(player_form)==2 else 128)<<16
	return {"limit":limit,"admitted":_i32(int(distance))<=limit}

static func sword_spatial(context: Variant) -> Dictionary:
	# Player88D2C only; actor reach uses a different horizontal approximation.
	# Selection, virtual height producers and the item callback remain external.
	if not context is Dictionary: return {"error":"Invalid sword spatial context."}
	var measured := horizontal_euclidean(context.get("points"),context.get("control_word"))
	if measured.has("error"): return measured
	var gate := sword_distance_gate(measured.distance,context.get("player_form"))
	if gate.has("error"): return gate
	var result := {"distance":measured.distance,"integer_invalid":measured.integer_invalid,"limit":gate.limit,"admitted":false}
	if not gate.admitted: return result
	var elevation := vertical(context.get("vertical"))
	if elevation.has("error"): return elevation
	result.classification=elevation.classification
	result.admitted=int(elevation.classification)==4
	return result

static func target_projection(points: Variant, sine: Variant, cosine: Variant) -> Dictionary:
	# Native111F54; coefficients must come from the source angle table.
	if not points is Array or points.size()!=4: return {"error":"Four projection coordinates required."}
	for value in points:
		if not _signed(value): return {"error":"Invalid projection coordinate."}
	if not _signed(sine) or not _signed(cosine): return {"error":"Invalid projection coefficient."}
	var dx := _i32(int(points[0])-int(points[2]))
	var dy := _i32(int(points[1])-int(points[3]))
	return {"distance":_i32(((dx*int(sine))>>16)+((dy*int(cosine))>>16))}

static func obstruction_box(points: Variant, width: Variant, height: Variant) -> Dictionary:
	# Native5CDDF after inverse transforms. Passing still requires height checks.
	if not points is Array or points.size()!=4: return {"error":"Four transformed coordinates required."}
	for value in points:
		if not _signed(value): return {"error":"Invalid transformed coordinate."}
	if not Numbers._integer(width,255) or not Numbers._integer(height,255): return {"error":"Invalid source obstruction dimensions."}
	var bx := (((int(width)+1)>>1)<<16)+32768
	var by := (((int(height)+1)>>1)<<16)+32768
	var x1 := int(points[0]);var y1 := int(points[1]);var x2 := int(points[2]);var y2 := int(points[3])
	return {"rejected":(x1 < -bx and x2 < -bx) or (x1>bx and x2>bx) or (y1 < -by and y2 < -by) or (y1>by and y2>by)}

static func inverse_transform(point: Variant, origin: Variant, sine: Variant, cosine: Variant) -> Dictionary:
	# Native111CAC XY only. Z subtraction is a separate caller operation.
	if not point is Array or point.size()!=2 or not origin is Array or origin.size()!=2: return {"error":"Two-dimensional point and origin required."}
	for value in point+origin:
		if not _signed(value): return {"error":"Invalid inverse-transform coordinate."}
	if not _signed(sine) or not _signed(cosine): return {"error":"Invalid source rotation coefficient."}
	var dx := _i32(int(point[0])-int(origin[0]))
	var dy := _i32(int(point[1])-int(origin[1]))
	return {"point":[_i32(((dx*int(cosine))>>16)-((dy*int(sine))>>16)),_i32(((dy*int(cosine))>>16)+((dx*int(sine))>>16))]}

static func obstruction_xy(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid obstruction transform context."}
	var first := inverse_transform(context.get("first"),context.get("origin"),context.get("sine"),context.get("cosine"))
	if first.has("error"): return first
	var second := inverse_transform(context.get("second"),context.get("origin"),context.get("sine"),context.get("cosine"))
	if second.has("error"): return second
	return obstruction_box(first.point+second.point,context.get("width"),context.get("height"))

static func obstruction_height(first_virtual60: Variant, target_relative_z: Variant, dimension31: Variant) -> Dictionary:
	# Native5CE71. First input is the virtual60 result, not actor-relative Z.
	if not _signed(first_virtual60) or not _signed(target_relative_z): return {"error":"Invalid obstruction height input."}
	if not Numbers._integer(dimension31,255): return {"error":"Invalid source obstruction height dimension."}
	var rejected := int(first_virtual60)<0 and int(target_relative_z)<0
	return {"rejected":rejected,"needs_virtual8":not rejected and int(first_virtual60)>((int(dimension31)>>1)<<16)}

static func player_height_bounds(proposed: Variant, lower: Variant, upper: Variant) -> Dictionary:
	# D639C final numeric stage only; D6180 region/state effects remain separate.
	for value in [proposed,lower,upper]:
		if not _signed(value): return {"error":"Invalid player height bound."}
	return {"height":maxi(mini(int(proposed),_i32(int(upper)-131072)),_i32(int(lower)+131072))}
