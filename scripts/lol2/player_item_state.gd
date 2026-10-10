extends RefCounted
## Modern owner around the source item callback. 60 ticks/s is provisional.
const Effects = preload("res://scripts/lol2/player_item_effects.gd")
const Aloe = preload("res://scripts/lol2/cave_aloe.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const TICKS_PER_SECOND := 60.0
## Fire crystal charges (item byte +4, the op3/give_item property): magic shop give_item("57a-Fire crstl", 4); a lit
## Museum sconce rekindles a burnt crystal with property 1. 0 = burnt ("57b-Fire brnt", same carried id).
const CRYSTAL_SHOP_CHARGES := 4
const CRYSTAL_RECHARGE_CHARGES := 1
static func aloe_initial() -> Dictionary:
	return {"pending":0,"base":0,"clock":0,"fraction":0.0}
static func initial() -> Dictionary:
	return {"version":1,"champion":Effects.empty(),"spent":[],"fraction":0.0,"aloe":aloe_initial(),"ancient_charges":0}
static func canonical(saved: Dictionary) -> Dictionary:
	var aloe: Dictionary = saved.get("aloe",aloe_initial()).duplicate(true)
	for key in ["pending","base","clock"]: aloe[key] = int(aloe[key])
	aloe.fraction = float(aloe.fraction)
	var result := {"version":1,"champion":Effects.restore(saved.champion).state,"spent":saved.spent.duplicate(),"fraction":float(saved.fraction),"aloe":aloe,"ancient_charges":int(saved.get("ancient_charges",0))}
	if saved.has("dragon_blood"): result.dragon_blood=saved.dragon_blood.duplicate(true)
	if saved.has("offhand"): result.offhand = saved.offhand
	if saved.has("dampened"): result.dampened = bool(saved.dampened)
	if saved.has("fire_crystals"):
		result.fire_crystals = {}
		for id in saved.fire_crystals: result.fire_crystals[id] = int(saved.fire_crystals[id])
	return result
static func validate(saved: Variant, collected: Array = []) -> String:
	if not saved is Dictionary or saved.get("version")!=1: return "Invalid item effects."
	var offhand = saved.get("offhand", "")
	if not offhand is String or (offhand != "" and (not preload("res://scripts/lol2/player_equipment.gd").offhand(offhand) or offhand not in collected)): return "Invalid offhand equipment."
	var effect := Effects.restore(saved.get("champion"))
	if effect.has("error"): return effect.error
	if not saved.get("spent") is Array or saved.spent.size()>Catalog.consumables().size(): return "Invalid consumed items."
	var seen: Array=[]
	for id in saved.spent:
		if Catalog.use_kind(id) == "" or id in seen or id in collected: return "Inconsistent consumed item."
		seen.append(id)
	var blood_error:=preload("res://scripts/lol2/dragon_blood_state.gd").validate(saved.get("dragon_blood",[]),saved.spent)
	if not blood_error.is_empty():return blood_error
	var charges = saved.get("ancient_charges",0)
	if not (charges is int or charges is float) or not is_finite(float(charges)) or charges != floorf(float(charges)) or charges < 0 or charges > 9: return "Invalid Ancient Stone charges."
	if charges > 0 and not saved.spent.any(func(id): return Catalog.use_kind(id) == "ancient"): return "Ancient charges lack consumed item history."
	# Dampen charm (handler27): the dampened flag (native player byte 0x23ABD bit0) only follows its consumption.
	var dampened = saved.get("dampened",false)
	if not dampened is bool or (dampened and preload("res://scripts/lol2/monastery_conversation.gd").DAMPEN not in saved.spent): return "Invalid Dampen charm state."
	if saved.has("fire_crystals"):
		var crystals = saved.fire_crystals
		if not crystals is Dictionary: return "Invalid fire crystal charges."
		for id in crystals:
			var n = crystals[id]
			if Catalog.use_kind(id) != "fire_crystal" or not (n is int or n is float) or float(n) != floorf(float(n)) or n < 0 or n > CRYSTAL_SHOP_CHARGES: return "Invalid fire crystal charges."
			if not collected.is_empty() and id not in collected: return "Fire crystal charges for an item not carried."
	var fraction = saved.get("fraction")
	if not (fraction is int or fraction is float) or not is_finite(float(fraction)) or fraction<0 or fraction>=1: return "Invalid item timer fraction."
	if saved.has("aloe"):
		var a = saved.aloe
		if not a is Dictionary: return "Invalid Aloe healing."
		for key in ["pending","base","clock"]:
			var n = a.get(key)
			var maximum := 0xffffffff if key == "pending" else 255 if key == "base" else 4095
			if not (n is int or n is float) or not is_finite(float(n)) or n != floorf(float(n)) or n < 0 or n > maximum: return "Invalid Aloe healing."
		var f = a.get("fraction")
		if not (f is int or f is float) or not is_finite(float(f)) or f < 0 or f >= 1: return "Invalid Aloe clock fraction."
	return ""
static func advance(saved: Dictionary, seconds: float) -> void:
	if not saved.champion.active or not is_finite(seconds) or seconds<=0: return
	var fixed: float=seconds*TICKS_PER_SECOND*65536.0+float(saved.fraction)
	var whole:=int(floorf(fixed))
	saved.fraction=fixed-float(whole)
	# Active callbacks expire on signed <=0. Avoid an oversized adapter delta wrapping.
	whole=mini(whole,0x7fffffff)
	var result:=Effects.maintain(saved.champion,whole)
	if not result.has("error"): saved.champion=result.state

static func transport_error(inventory: Dictionary, quests: Dictionary) -> String:
	var effects: Dictionary = inventory.get("item_effects",{})
	if Effects.Ancient.ITEM in effects.get("spent",[]):
		if not quests.get("hive_rune_entry",{}).get("flag7",false): return "Consumed Ancient Stone lacks pickup history."
	# A consumed Jungle world item must keep its collected row, or the pickup would respawn.
	var rows: Array = quests.get("jungle_world_items",{}).get("collected",[]).map(func(r): return int(r)) if quests.get("jungle_world_items") is Dictionary and quests.jungle_world_items.get("collected") is Array else []
	for id in effects.get("spent",[]):
		if Catalog.WorldItems.valid(id) and int(Catalog.WorldItems.ITEMS[id].row) not in rows: return "Consumed Jungle item lacks pickup history."
	return ""
