extends RefCounted
## G15 shared contract. Quest owners decide targets/effects; this table adds no
## damage or native-cost claim. Optional on old magic packets, so old bytes stay valid.
const SCHOOLS := ["spark", "heal", "curse", "mists", "prism", "summon"]
const NAMES := {"spark":"Spark", "heal":"Healing", "curse":"Curse", "mists":"Mists", "prism":"Prism", "summon":"Summon"}
const CASTS := {"curse1":1, "curse2":2, "curse3":2, "curse5":5, "mists1":1, "mists3":3, "prism5":5, "summon3":3}
const GROUPS := {"dampen":["curse1"], "control":["curse2","curse3","curse5"], "mists":["mists1","mists3"], "prism":["prism5"], "summon":["summon3"]}
const STORED_CHARGES := {"heal":1,"spark":3, "mists":1, "prism":5, "summon":3}

static func initial() -> Dictionary:
	return {"version":1, "learned":[]}

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or not value.get("version") is float and not value.get("version") is int:
		return "Invalid learned spells."
	if value.version != 1 or not value.get("learned") is Array:
		return "Invalid learned spells."
	var seen := {}
	for id in value.learned:
		if not id is String or not CASTS.has(id) or seen.has(id): return "Invalid learned cast."
		seen[id] = true
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	return {"version":1, "learned":value.learned.duplicate()}

static func schools(value: Dictionary) -> Array:
	var result := ["spark","heal"]
	for school: String in SCHOOLS:
		if school in result: continue
		for id: String in value.learned:
			if id.begins_with(school): result.append(school); break
	return result

static func learn(value: Dictionary, group: String) -> Dictionary:
	if not validate(value).is_empty() or not GROUPS.has(group): return {}
	var next := canonical(value)
	for id in GROUPS[group]:
		if not id in next.learned: next.learned.append(id)
	return next

static func cast_id(school: String, charge: int, form: int) -> String:
	if form not in [0,2]: return ""
	if school == "curse" and charge == 3: return "curse3" if form == 0 else "curse2"
	var id := school + str(charge)
	return id if CASTS.has(id) else ""

static func request(book: Dictionary, school: String, charge: int, form: int) -> Dictionary:
	var id := cast_id(school,charge,form)
	if id.is_empty(): return {"error":"That charge is not available"}
	if not validate(book).is_empty() or not id in book.learned: return {"error":"That spell is not learned"}
	return {"id":id, "cost":int(CASTS[id])}
