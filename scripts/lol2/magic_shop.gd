extends RefCounted
## Rashar MAGIC_ entry/offer decisions. Effects are explicit; room integration
## and host callback timing remain owned by the Jungle scene.

static func entry(flags: Dictionary) -> Dictionary:
	var result := {"handled":true,"dialogue":[],"set_flags":[]}
	if flags.get("52",0) != 0:
		return result
	if flags.get("55",0) != 0 and flags.get("56",0) == 0:
		result.dialogue = [440,441]
		return result
	if flags.get("56",0) != 0 and flags.get("57",0) == 0:
		return result
	if flags.get("58",0) != 0:
		return result
	result.dialogue = [400,401,402,403,404,405,406,407,408,409,410,411,412,413,414,416,417,418,419,420,421,422]
	result.set_flags = [53,54,58]
	return result

static func broken_thohan(held: String, flags: Dictionary) -> Dictionary:
	var result := {"handled":false,"dialogue":[],"set_globals":[]}
	if held != "12-Tho Broken" or flags.get("52",0) != 0 or flags.get("49",0) == 0:
		return result
	result.handled = true
	result.dialogue = [423,424,425,426,427,428]
	result.set_globals = ["GV_KNOWLEDGE_OF_POWER_ORB"]
	return result
