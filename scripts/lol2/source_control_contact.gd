extends RefCounted
## ADA30 support-owner transition adapter using original rotated support faces.
## Grounded floor tolerance4 replaces the native vertical crossing solver.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
static func initial() -> Dictionary: return {"version":1,"owner":-1}
static func validate(saved: Variant, src: Dictionary) -> String:
	if not saved is Dictionary or not Values.integer(saved.get("version"),1) or saved.version!=1: return "Invalid support contact version."
	var owner=saved.get("owner")
	if not (owner is int or owner is float) or not is_finite(float(owner)) or float(owner)!=floorf(float(owner)): return "Invalid support contact owner."
	if owner==-1:return ""
	for row in src.plates:
		if owner==int(row.id):return ""
	return "Unknown support contact owner."
static func canonical(saved: Dictionary) -> Dictionary: return {"version":1,"owner":int(saved.owner)}
static func admitted(value: int, form: int) -> bool:
	match value:
		4:return true
		7:return form==2
		8:return form==0
		9:return form==1
		10:return form!=2
		11:return form!=0
		12:return form!=1
	return false
static func update(saved: Dictionary, src: Dictionary, point: Vector2, foot: float, grounded: bool, form: int, owner_states: Dictionary) -> Array:
	if not point.is_finite() or not is_finite(foot) or form not in [0,1,2]: return []
	var selected: int=-1
	if grounded:
		for row in src.plates:
			var polygon:=PackedVector2Array()
			for p in row.polygon:polygon.append(Vector2(p[0],p[1]))
			if absf(foot-float(row.height))<=4.0 and Geometry2D.is_point_in_polygon(point,polygon):selected=int(row.id);break
	if selected==int(saved.owner):return []
	var effects: Array=[]
	if int(saved.owner)>=0:effects.append({"owner":int(saved.owner),"value":5,"groups":[]})
	saved.owner=selected
	if selected<0:return effects
	for row in src.plates:
		if int(row.id)!=selected:continue
		for record in row.records:
			if admitted(int(record.value),form) and int(owner_states.get(str(selected),0))==0:
				effects.append({"owner":selected,"value":int(record.value),"groups":[int(record.group)]})
	return effects
