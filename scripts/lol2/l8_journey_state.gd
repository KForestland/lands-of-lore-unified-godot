extends RefCounted
## Modern implementation of hintbook printed86-89/98, owner rule2026-11-01.
## Owns only the first-visit gift/admission/key consequences. No native quest-byte
## seed, dialogue quotation, invented combat result, or native timing is implied.
const BLADE := "jungle:kityara:Empty_hand"
const KEY := "l8:shaman:Dracoid_sigil" # Original definition102 = 100-Drac sigil.
const LIMIT := 64
static func initial() -> Dictionary:
	return {"version":1,"gift":"unoffered","temple_visited":false,"admitted":false,"key_awarded":false}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size()!=5 or value.get("version")!=1: return "Invalid L8 journey."
	if value.get("gift") not in ["unoffered","delivered","dropped","recovered","returned"]: return "Invalid L8 gift history."
	for key in ["temple_visited","admitted","key_awarded"]:
		if not value.get(key) is bool: return "Invalid L8 journey flag."
	if value.admitted and (not value.temple_visited or value.gift not in ["recovered","returned"]): return "Village admission lacks its prerequisites."
	if value.gift == "returned" and not value.admitted: return "Blade returned outside the village."
	if value.key_awarded and not value.admitted: return "Cemetery key lacks the shaman meeting."
	return ""
## Return a transaction. Caller commits both state and inventory only on success.
## Physical reach, actor selection and scene presentation are caller responsibilities.
static func act(value: Dictionary, carried: Array, action: String, offered: String = "") -> Dictionary:
	var error := validate(value)
	if not error.is_empty(): return {"ok":false,"reason":error}
	if carried.size()>LIMIT: return {"ok":false,"reason":"Inventory exceeds capacity."}
	var seen := {}
	for id in carried:
		if not id is String or seen.has(id): return {"ok":false,"reason":"Invalid inventory identity."}
		seen[id] = true
	var state := value.duplicate(true)
	var inventory := carried.duplicate()
	var notice := ""
	match action:
		"offer_daniel":
			if offered!=BLADE or BLADE not in inventory: return {"ok":false,"reason":"Offer Daniel his grandfather's blade."}
			if state.gift == "unoffered":
				state.gift = "delivered"
				notice = "Daniel accepts his grandfather's blade."
			elif state.gift == "recovered" and state.admitted:
				state.gift = "returned"
				notice = "You return the blade to Daniel in the village."
			else: return {"ok":false,"reason":"The blade cannot be given here yet."}
			inventory.erase(BLADE)
		"hopper_interruption":
			if state.gift != "delivered": return {"ok":false,"reason":"Daniel has not accepted the gift."}
			state.gift = "dropped"
			notice = "Hoppers interrupt the meeting. Daniel drops the blade as he leaves."
		"recover_blade":
			if state.gift != "dropped" or BLADE in inventory: return {"ok":false,"reason":"There is no dropped blade to recover."}
			if inventory.size()>=LIMIT: return {"ok":false,"reason":"Inventory full."}
			inventory.append(BLADE)
			state.gift = "recovered"
			notice = "You recover Daniel's blade."
		"visit_temple":
			if state.temple_visited: return {"ok":false,"reason":"The first temple visit is already recorded."}
			state.temple_visited = true
			notice = "At the temple, a creature seizes the priest."
		"show_guard":
			if state.admitted: return {"ok":false,"reason":"The guard has already admitted you."}
			if not state.temple_visited or state.gift != "recovered": return {"ok":false,"reason":"The village encounter is not ready."}
			if offered!=BLADE or BLADE not in inventory: return {"ok":false,"reason":"Show the guard Daniel's blade."}
			state.admitted = true
			notice = "The guard recognizes the blade and admits you to the village."
		"visit_shaman":
			if not state.admitted: return {"ok":false,"reason":"Enter the village first."}
			if state.key_awarded: return {"ok":false,"reason":"The shaman has already given you the cemetery key."}
			if KEY in inventory: return {"ok":false,"reason":"The cemetery key is already carried."}
			if inventory.size()>=LIMIT: return {"ok":false,"reason":"Inventory full."}
			inventory.append(KEY)
			state.key_awarded = true
			notice = "The shaman asks for silverleaf and gives you the cemetery key."
		_: return {"ok":false,"reason":"Unknown L8 journey action."}
	return {"ok":true,"state":state,"inventory":inventory,"notice":notice}
