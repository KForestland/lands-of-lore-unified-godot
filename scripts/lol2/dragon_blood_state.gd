extends RefCounted
## Modern placed explosive: six active seconds, 120-unit blast. One record per consumed vial.
const ITEMS := ["museum:skeleton20:Dragon_Blood_1","museum:skeleton20:Dragon_Blood_2","museum:item1:Dragon_Blood","museum:item2:Dragon_Blood","museum:item3:Dragon_Blood"]
const FUSE := 6.0
const AREAS := ["res://scenes/lol2/museum_walkthrough.tscn","res://scenes/lol2/jungle_walkthrough.tscn","res://scenes/lol2/hive_review.tscn"]
static func validate(bombs: Variant,spent: Array) -> String:
	if not bombs is Array or bombs.size()>ITEMS.size():return "Invalid Dragon Blood bombs."
	var seen: Array=[]
	for bomb in bombs:
		if not bomb is Dictionary or bomb.size()!=4 or bomb.get("id") not in ITEMS or bomb.id in seen or bomb.id not in spent:return "Invalid Dragon Blood owner."
		if bomb.get("area") not in AREAS:return "Invalid Dragon Blood area."
		var time=bomb.get("remaining")
		if not (time is int or time is float) or not is_finite(float(time)) or time<=0 or time>FUSE:return "Invalid Dragon Blood fuse."
		var p=bomb.get("position")
		if not p is Array or p.size()!=3:return "Invalid Dragon Blood position."
		for n in p:
			if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n))>32768:return "Invalid Dragon Blood position."
		seen.append(bomb.id)
	return ""
