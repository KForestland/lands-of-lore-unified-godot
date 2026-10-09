extends RefCounted
## Carried-item identities: one place for "is this an item", its equipment slot,
## presentation and the first area scope that can own it. Family modules keep their
## id rules; ownership stays with the area/encounter owners and save shapes are unchanged.
## Must not preload save, host, player_equipment or player_defense scripts (they will
## delegate here). Literal ids below are pinned against their owners by item_catalog_test.
const Captain = preload("res://scripts/lol2/cave_captain_items.gd")
const Defenses = preload("res://scripts/lol2/item_defense_data.gd")
const Stalagmite = preload("res://scripts/lol2/cave_stalagmite.gd")
const Aloe = preload("res://scripts/lol2/cave_aloe.gd")
const WeaponShop = preload("res://scripts/lol2/weapon_shop_state.gd")
const MagicShop = preload("res://scripts/lol2/magic_shop_state.gd")
const ShopItems = preload("res://scripts/lol2/shop_item_inventory.gd")
const WorldItems = preload("res://scripts/lol2/jungle_world_items_catalog.gd")
const Runes = preload("res://scripts/lol2/hive_rune_items.gd")
const Wax = preload("res://scripts/lol2/hive_wax.gd")
const BeeWax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
const Monastery = preload("res://scripts/lol2/monastery_conversation.gd")
## Jungle covers every later Act 1 area (Hive, monastery, shops, darker jungle).
const SCOPES := ["cave","museum","jungle"]
## Shared hand-held limit; jungle_save already uses 64. Museum's old 22 is below its
## admitted universe of 28 (cave 20 + museum 8).
const MAX_CARRIED := 64
const GENERATED := "res://assets/lol2/generated/"
const FIXED := {
	"museum:item1:Dragon_Blood":{"slot":"","label":"Dragon Blood","icon":GENERATED+"museum_blood_loot/icon.png","origin":"museum","use":"dragon_blood"},
	"museum:item2:Dragon_Blood":{"slot":"","label":"Dragon Blood","icon":GENERATED+"museum_blood_loot/icon.png","origin":"museum","use":"dragon_blood"},
	"museum:item3:Dragon_Blood":{"slot":"","label":"Dragon Blood","icon":GENERATED+"museum_blood_loot/icon.png","origin":"museum","use":"dragon_blood"},
	"museum:skeleton20:Dragon_Blood_1":{"slot":"","label":"Dragon Blood","icon":GENERATED+"museum_blood_loot/icon.png","origin":"museum","use":"dragon_blood"},
	"museum:skeleton20:Dragon_Blood_2":{"slot":"","label":"Dragon Blood","icon":GENERATED+"museum_blood_loot/icon.png","origin":"museum","use":"dragon_blood"},
	"cave:guard38:Short_Sword":{"slot":"weapon","label":"Short Sword","icon":GENERATED+"cave_captain_items/Short_Sword.png","origin":"cave"},
	"cave:guard39:Short_Sword":{"slot":"weapon","label":"Short Sword","icon":GENERATED+"cave_captain_items/Short_Sword.png","origin":"cave"},
	# Guards52/53 arrival grants (prop699/g7878, prop1067/g8908): one Short Sword and one Guard Shield each.
	"cave:guard52:Short_Sword":{"slot":"weapon","label":"Short Sword","icon":GENERATED+"cave_captain_items/Short_Sword.png","origin":"cave"},
	"cave:guard52:Guard_Shield":{"slot":"offhand","label":"Guard Shield","icon":GENERATED+"cave_guard_shield/Guard_Shield.png","origin":"cave"},
	"cave:guard53:Short_Sword":{"slot":"weapon","label":"Short Sword","icon":GENERATED+"cave_captain_items/Short_Sword.png","origin":"cave"},
	"cave:guard53:Guard_Shield":{"slot":"offhand","label":"Guard Shield","icon":GENERATED+"cave_guard_shield/Guard_Shield.png","origin":"cave"},
	# Guard54's two separate arrival grants (prop1013 property4, actor54 property1; cave_guard54_loot.gd).
	"cave:guard54:prop1013:Short_Sword":{"slot":"weapon","label":"Short Sword","icon":GENERATED+"cave_captain_items/Short_Sword.png","origin":"cave"},
	"cave:guard54:actor54:Short_Sword":{"slot":"weapon","label":"Short Sword","icon":GENERATED+"cave_captain_items/Short_Sword.png","origin":"cave"},
	"draracle/prop/1108/sample":{"slot":"","label":"Cavern find (unidentified)","icon":"","origin":"cave"},
	"jungle:kelsrick:Fine_Longsword":{"slot":"weapon","label":"Fine Longsword","icon":GENERATED+"museum_sword_transfer/sword.png","origin":"jungle"},
	"museum:item11:Fine_Longsword":{"slot":"weapon","label":"Fine Longsword","icon":GENERATED+"museum_sword_transfer/sword.png","origin":"museum"},
	"museum:item10:Mail_Shirt":{"slot":"armor","label":"Mail Shirt","icon":GENERATED+"museum_mail/mail.png","origin":"museum","defense":20},
	"museum:item8:Champion_Stone":{"slot":"","label":"Champion Stone","icon":GENERATED+"museum_stones/stone.png","origin":"museum","use":"champion_stone"},
	"museum:item9:Champion_Stone":{"slot":"","label":"Champion Stone","icon":GENERATED+"museum_stones/stone.png","origin":"museum","use":"champion_stone"},
	"museum:control181:Tho_Broken":{"slot":"","label":"Broken Thohan","icon":GENERATED+"museum_broken_thohan/icon.png","origin":"museum"},
	# The single original "92-Sk key" (preloaded in control87) and movable55's "68-SS1" (museum_key_locks_source.json).
	"museum:control87:Sk_key":{"slot":"","label":"Sk key","icon":GENERATED+"museum_key_locks/sk_key.png","origin":"museum"},
	# Prop153 pedestal grant "7-Long arm" (museum_long_arm_source.json); same modern weapon slot as the shop Long arm.
	"museum:prop153:Long_arm":{"slot":"weapon","label":"Long arm","icon":GENERATED+"museum_long_arm/icon.png","origin":"museum"},
	"museum:movable55:SS1":{"slot":"","label":"SS1","icon":GENERATED+"museum_key_locks/ss1.png","origin":"museum"},
	"jungle:item51:Th_Dagger":{"slot":"weapon","label":"Th Dagger","icon":GENERATED+"jungle_source_pickups/th_dagger.png","origin":"jungle"},
	"jungle:weapon_shop:Gargoyle_Bracers":{"slot":"offhand","label":"Gargoyle Bracers","icon":GENERATED+"weapon_shop/Gargoyle_Bracers.png","origin":"jungle","defense":5},
	# MLIB message8 Dawn rune-translation gift (monastery_conversation.DAMPEN), GLOBAL definition72 handler27.
	"monastery:item70:Dampen_charm":{"slot":"","label":"Dampen charm","icon":GENERATED+"monastery_dampen/dampen.png","origin":"jungle","use":"dampen_charm"},
	"hive:runes:Ancients_Stone":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
}
## Original definition name shared by cave and Jungle Aloe (definition110, handler9).
const ALOE_SOURCE_NAME := "108-Cave aloe"
const KITYARA_KNIFE := "jungle:kityara:Empty_hand"
## Magic-shop weapons; the remaining shop/world ids are carried, not equipped.
const MAGIC_WEAPONS := ["jungle:magic_shop:Dag_Light","jungle:magic_shop:Tho_fixed"]

static func entry(id: Variant) -> Dictionary:
	if not id is String: return {}
	if FIXED.has(id): return FIXED[id]
	if Captain.valid(id):
		return {"slot":"weapon" if id == Captain.SWORD else "armor","label":Captain.label(id),"icon":Captain.icon(id),"origin":"cave","defense":8 if id == Captain.ARMOR else 0}
	if Stalagmite.valid_item(id): return {"slot":"weapon","label":"Stalagmite","icon":Stalagmite.ROOT+"icon.png","origin":"cave"}
	if Aloe.valid_item(id): return {"slot":"","label":"Cave Aloe","icon":"","origin":"cave","use":"aloe"}
	if id in WeaponShop.ITEMS.values():
		return {"slot":"weapon","label":id.get_slice(":",2).replace("_"," "),"icon":GENERATED+"weapon_shop/"+id.get_slice(":",2)+".png","origin":"jungle"}
	if id == Monastery.FLUTE: return {"slot":"","label":"Iron Flute","icon":"","origin":"jungle"}
	# Kityara's knife: GLOBAL definition29 "30-Empty hand", identity3959297008 (jungle_kityara_source.json item).
	if id == KITYARA_KNIFE: return {"slot":"weapon","label":"Kityara's blade","icon":GENERATED+"jungle_kityara/empty_hand.png","origin":"jungle"}
	if id == Wax.ITEM: return {"slot":"","label":"Wax","icon":GENERATED+"hive_wax/wax.png","origin":"jungle"}
	# Renewable beehive wax pool (jungle_beehive_wax.gd): original "71-Wax", Jungle scope.
	if BeeWax.valid(id): return {"slot":"","label":"Wax","icon":BeeWax.ICON,"origin":"jungle"}
	if Runes.valid(id): return {"slot":"","label":"Wax runes","icon":GENERATED+"hive_wax_runes/runes.png","origin":"jungle"}
	# Power Orb, magic-shop and jungle world items share the existing shop presentation.
	if id == Monastery.ORB or id in MagicShop.all_item_ids() or WorldItems.valid(id):
		var info: Dictionary = ShopItems.info(id)
		var result := {"slot":"weapon" if id in MAGIC_WEAPONS else "","label":str(info.label),"icon":str(info.icon),"origin":"jungle"}
		# Jungle rows63-67 are the cave Aloe's own definition110/identity3732130108/handler9.
		if WorldItems.valid(id) and WorldItems.source_name(id) == ALOE_SOURCE_NAME: result.use = "aloe"
		# Definition111/handler98 consumes the held sap without a stat effect.
		if WorldItems.valid(id) and WorldItems.source_name(id) == "109-Ironwod sap": result.use = "ironwood_sap"
		# Rows54-57: definition84/handler20 consumes the held fruit and clears player status +1B5 (no heal/bonus).
		if WorldItems.valid(id) and WorldItems.source_name(id) == "82-Vels fruit": result.use = "vels_fruit"
		return result
	return {}

static func known(id: Variant) -> bool: return not entry(id).is_empty()
static func slot(id: Variant) -> String: return str(entry(id).get("slot",""))
static func label(id: Variant) -> String: return str(entry(id).get("label",""))
static func icon(id: Variant) -> String: return str(entry(id).get("icon",""))
static func defense(id: Variant) -> int: return int(Defenses.ITEMS.get(id,{}).get("defense",0)) if id is String else 0
static func mitigation(id: Variant) -> Array:
	return Defenses.ITEMS.get(id,{}).get("descriptors",[]).duplicate(true) if id is String else []
## Implemented inventory use; empty means no verified use.
static func use_kind(id: Variant) -> String: return str(entry(id).get("use",""))
## Every identity with an implemented use; bounds the saved consumed-item history.
static func consumables() -> Array: return ids("jungle").filter(func(id): return use_kind(id) != "")

## Known and obtainable no later than `scope` (cave < museum < jungle).
static func admitted(id: Variant, scope: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and scope in SCOPES and SCOPES.find(str(e.origin)) <= SCOPES.find(scope)

## Every identity a scope admits; finite by construction.
static func ids(scope: String = "jungle") -> Array:
	var all: Array = FIXED.keys() + [Captain.SWORD,Captain.ARMOR]
	for record in Stalagmite.RECORDS: all.append(Stalagmite.item_id(record,1))
	for record in Aloe.RECORDS:
		for harvest in range(1,4): all.append(Aloe.item_id(record,harvest))
	all += WeaponShop.ITEMS.values().filter(func(id): return id not in FIXED)
	all += [Monastery.FLUTE,Monastery.ORB,Wax.ITEM,KITYARA_KNIFE] + MagicShop.all_item_ids() + WorldItems.ITEMS.keys() + BeeWax.POOL
	for index in range(23): all.append(Runes.PREFIX+str(index))
	return all.filter(func(id): return admitted(id,scope))

static func validate_carried(ids: Variant, scope: String, limit: int = MAX_CARRIED) -> String:
	if not ids is Array or ids.size() > limit or scope not in SCOPES: return "Invalid collected items."
	var seen: Dictionary = {}
	for id in ids:
		if not admitted(id,scope) or seen.has(id): return "Invalid collected items."
		seen[id] = true
	return ""

## Each slot is "" or an admitted id of that slot that the player owns.
static func validate_slots(ids: Array, scope: String, weapon: Variant, armor: Variant, offhand: Variant = "") -> String:
	for pair in [[weapon,"weapon","Invalid equipped weapon."],[armor,"armor","Invalid equipped armor."],[offhand,"offhand","Invalid offhand equipment."]]:
		var id = pair[0]
		if not id is String: return pair[2]
		if id != "" and (slot(id) != pair[1] or not admitted(id,scope) or id not in ids): return pair[2]
	return ""
