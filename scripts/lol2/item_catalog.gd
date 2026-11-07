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
const Amber = preload("res://scripts/lol2/hive_amber_items.gd")
const BeeWax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
const Harvest = preload("res://scripts/lol2/jungle_harvest_items.gd")
const Monastery = preload("res://scripts/lol2/monastery_conversation.gd")
const MuseumAloe = preload("res://scripts/lol2/museum_aloe_state.gd")
const MuseumScrolls = preload("res://scripts/lol2/museum_scroll_state.gd")
const HiveItems = preload("res://scripts/lol2/hive_world_items_state.gd")
const DarkHalls = preload("res://scripts/lol2/dark_halls_items.gd")
const Definitions = preload("res://scripts/lol2/item_definitions.gd")
const ThievesDen = preload("res://scripts/lol2/thieves_den_state.gd")
const AreaItems = preload("res://scripts/lol2/area_world_items_state.gd")
## Jungle covers every later Act 1 area (Hive, monastery, shops, darker jungle). "world" admits the generic
## per-definition ids below (later acts); no Act 1 save validates against it.
const SCOPES := ["cave","museum","jungle","world"]
## Generic carried id for any of the 170 original definitions: "item:defNNN". Owners in later acts grant these;
## Act 1 keeps its per-placement ids (save compatibility).
const GENERIC_PREFIX := "item:def"
const Act2Items = preload("res://scripts/lol2/act2_items_catalog.gd")
## Original definition name of each fixed Act 1 identity (source JSONs named in the FIXED comments).
const FIXED_NAMES := {
	"museum:item4:Fire_Crystal":"57b-Fire brnt","museum:item5:Fire_Crystal":"57b-Fire brnt","museum:item6:Fire_Crystal":"57b-Fire brnt",
	"museum:prop280:Prism":"8-Prism","museum:item1:Dragon_Blood":"Drag Blood","museum:item2:Dragon_Blood":"Drag Blood",
	"museum:item3:Dragon_Blood":"Drag Blood","museum:skeleton20:Dragon_Blood_1":"Drag Blood","museum:skeleton20:Dragon_Blood_2":"Drag Blood",
	"cave:guard38:Short_Sword":"5-Short swd","cave:guard39:Short_Sword":"5-Short swd","cave:guard52:Short_Sword":"5-Short swd",
	"cave:guard52:Guard_Shield":"38-Guard shield","cave:guard53:Short_Sword":"5-Short swd","cave:guard53:Guard_Shield":"38-Guard shield",
	"cave:guard54:prop1013:Short_Sword":"5-Short swd","cave:guard54:actor54:Short_Sword":"5-Short swd",
	"jungle:kelsrick:Fine_Longsword":"6-Fine longswd","museum:item11:Fine_Longsword":"6-Fine longswd","museum:item25:Dragon_Gem":"84-Dragon gem",
	"museum:item17:Ivory_Chip":"105-Ivory chip","museum:item18:Ivory_Chip":"105-Ivory chip","museum:item10:Mail_Shirt":"41-Mail shirt",
	"museum:item8:Champion_Stone":"121-Champion st","museum:item9:Champion_Stone":"121-Champion st","museum:item7:Lightning_Crystal":"56a-Ltng cr",
	"museum:control181:Tho_Broken":"12-Tho Broken","museum:control87:Sk_key":"92-Sk key","museum:prop153:Long_arm":"7-Long arm",
	"museum:movable55:SS1":"68-SS1","hive:control121:Reaver_of_GO":"18-Reaver of GO","hive:prop214:Net_of_Exile":"26-Net of Exile",
	"cave:prop1050:Ancients_Stone":"66-Ancients stn","cave:control75:Mana_foil":"131-Mana foil","jungle:item51:Th_Dagger":"10-Th Dagger",
	"jungle:weapon_shop:Gargoyle_Bracers":"42-Gargoyle br","monastery:item70:Dampen_charm":"70-Dampen ch","hive:runes:Ancients_Stone":"66-Ancients stn",
	"jungle:chut:Ancients_Stone_1":"66-Ancients stn","jungle:chut:Ancients_Stone_2":"66-Ancients stn","jungle:chut:Ancients_Stone_3":"66-Ancients stn",
	"jungle:chut:Ancients_Stone_4":"66-Ancients stn","jungle:chut:Ancients_Stone_5":"66-Ancients stn","jungle:chut:Ancients_Stone_6":"66-Ancients stn",
}
## Shared hand-held limit; jungle_save already uses 64. Museum's old 22 is below its
## admitted universe of 28 (cave 20 + museum 8).
const MAX_CARRIED := 64
const GENERATED := "res://assets/lol2/generated/"
const FIXED := {
	"act2:L12_CM:blue_bow":{"slot":"weapon","label":"Blue Bow","icon":"res://assets/lol2/generated/items/icons/035.png","origin":"jungle","definition":35},
	"act2:L12_CM:item5":{"slot":"armor","label":"Obsidian Chain Mail","icon":"res://assets/lol2/generated/items/icons/054.png","origin":"jungle","definition":54},
	"act2:L13_RC:dark_sword":{"slot":"weapon","label":"Dark Sword","icon":GENERATED+"items/icons/021.png","origin":"jungle","definition":21},
	# Belial's Horn (definition 22) is held in the hand to start the final fight like the blue bow and the Dark Sword (book
	# STORY-092; grok X05/AR02). Hand slot so a save with the horn equipped is valid (adapter, ledger 2026-11-07).
	"act2:L19_BC:horn":{"slot":"weapon","label":"Hrn Belial","icon":GENERATED+"items/icons/022.png","origin":"jungle","definition":22},
	"act2:L13_RC:enchanted_thohan":{"slot":"weapon","label":"Enchanted Thohan’s Sword","icon":GENERATED+"items/icons/071.png","origin":"jungle","definition":71},
	"museum:item4:Fire_Crystal":{"slot":"","label":"Fire crystal","icon":GENERATED+"museum_crystal/burnt.png","origin":"museum","use":"fire_crystal","initial_charges":0},
	"museum:item5:Fire_Crystal":{"slot":"","label":"Fire crystal","icon":GENERATED+"museum_crystal/burnt.png","origin":"museum","use":"fire_crystal","initial_charges":0},
	"museum:item6:Fire_Crystal":{"slot":"","label":"Fire crystal","icon":GENERATED+"museum_crystal/burnt.png","origin":"museum","use":"fire_crystal","initial_charges":0},
	# Museum prop280 grant "8-Prism" (museum_prism_source.json); handler7 on-hit blind: prism_blind.gd.
	"museum:prop280:Prism":{"slot":"weapon","label":"Prism","icon":GENERATED+"museum_prism/icon.png","origin":"museum"},
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
	"museum:item25:Dragon_Gem":{"slot":"","label":"Dragon Gem","icon":GENERATED+"museum_dragon_heart/gem.png","origin":"museum"},
	"museum:item17:Ivory_Chip":{"slot":"","label":"Ivory Chip","icon":GENERATED+"museum_ivory/ivory.png","origin":"museum"},
	"museum:item18:Ivory_Chip":{"slot":"","label":"Ivory Chip","icon":GENERATED+"museum_ivory/ivory.png","origin":"museum"},
	"museum:item10:Mail_Shirt":{"slot":"armor","label":"Mail Shirt","icon":GENERATED+"museum_mail/mail.png","origin":"museum","defense":20},
	"museum:item8:Champion_Stone":{"slot":"","label":"Champion Stone","icon":GENERATED+"museum_stones/stone.png","origin":"museum","use":"champion_stone"},
	"museum:item9:Champion_Stone":{"slot":"","label":"Champion Stone","icon":GENERATED+"museum_stones/stone.png","origin":"museum","use":"champion_stone"},
	"museum:item7:Lightning_Crystal":{"slot":"","label":"Lightning crystal","icon":GENERATED+"museum_lightning_crystal/crystal.png","origin":"museum"},
	"museum:control181:Tho_Broken":{"slot":"","label":"Broken Thohan","icon":GENERATED+"museum_broken_thohan/icon.png","origin":"museum"},
	# The single original "92-Sk key" (preloaded in control87) and movable55's "68-SS1" (museum_key_locks_source.json).
	"museum:control87:Sk_key":{"slot":"","label":"Sk key","icon":GENERATED+"museum_key_locks/sk_key.png","origin":"museum"},
	# Prop153 pedestal grant "7-Long arm" (museum_long_arm_source.json); same modern weapon slot as the shop Long arm.
	"museum:prop153:Long_arm":{"slot":"weapon","label":"Long arm","icon":GENERATED+"museum_long_arm/icon.png","origin":"museum"},
	"museum:movable55:SS1":{"slot":"","label":"SS1","icon":GENERATED+"museum_key_locks/ss1.png","origin":"museum"},
	# Hive control121 grant "18-Reaver of GO" (hive_reaver_amber_source.json; handler18 equip flag only): a weapon.
	"hive:control121:Reaver_of_GO":{"slot":"weapon","label":"Reaver of GO","icon":GENERATED+"hive_reaver_amber/reaver.png","origin":"jungle"},
	# Hive prop214 pile grant "26-Net of Exile" (hive_net_exile_source.json); handler104 on-hit hold: net_exile_hold.gd.
	"hive:prop214:Net_of_Exile":{"slot":"weapon","label":"Net of Exile","icon":GENERATED+"hive_net_exile/net.png","origin":"jungle"},
	# Cave prop1050 "66-Ancients stn" (definition68/handler6, as the Hive stone) and control75 "131-Mana foil"
	# (definition133/handler43, native +50 mana) (cave_stone_manafoil_source.json).
	"cave:prop1050:Ancients_Stone":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"cave_stone_manafoil/stone_icon.png","origin":"cave","use":"ancient"},
	"cave:control75:Mana_foil":{"slot":"","label":"Mana Foil","icon":GENERATED+"cave_stone_manafoil/foil_icon.png","origin":"cave","use":"mana_foil"},
	"jungle:item51:Th_Dagger":{"slot":"weapon","label":"Th Dagger","icon":GENERATED+"jungle_source_pickups/th_dagger.png","origin":"jungle"},
	"jungle:weapon_shop:Gargoyle_Bracers":{"slot":"offhand","label":"Gargoyle Bracers","icon":GENERATED+"weapon_shop/Gargoyle_Bracers.png","origin":"jungle","defense":5},
	# MLIB message8 Dawn rune-translation gift (monastery_conversation.DAMPEN), GLOBAL definition72 handler27.
	"monastery:item70:Dampen_charm":{"slot":"","label":"Dampen charm","icon":GENERATED+"monastery_dampen/dampen.png","origin":"jungle","use":"dampen_charm"},
	"hive:runes:Ancients_Stone":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
	# Chief's hut CHUT callback 3: six "66-Ancients stn" from the stone piles once Anyar is dead (docs/jungle-chut-room.md).
	"jungle:chut:Ancients_Stone_1":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
	"jungle:chut:Ancients_Stone_2":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
	"jungle:chut:Ancients_Stone_3":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
	"jungle:chut:Ancients_Stone_4":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
	"jungle:chut:Ancients_Stone_5":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
	"jungle:chut:Ancients_Stone_6":{"slot":"","label":"Ancients’ Stone","icon":GENERATED+"hive_ancient_stone/stone.png","origin":"jungle","use":"ancient"},
}
## Original definition name shared by cave and Jungle Aloe (definition110, handler9).
const ALOE_SOURCE_NAME := "108-Cave aloe"
const L8_SHAMAN_KEY := "l8:shaman:Dracoid_sigil"
const KITYARA_KNIFE := "jungle:kityara:Empty_hand"
## Magic-shop weapons; the remaining shop/world ids are carried, not equipped.
const MAGIC_WEAPONS := ["jungle:magic_shop:Dag_Light","jungle:magic_shop:Tho_fixed"]

static func entry(id: Variant) -> Dictionary:
	if preload("res://scripts/lol2/l8_herbalist.gd").valid(id):
		var herb = preload("res://scripts/lol2/l8_herbalist.gd")
		var index: int = herb.definition(id)
		var info := {"slot":"","label":Definitions.label(index),"icon":Definitions.icon(index),"origin":"jungle","definition":index}
		if herb.kind(id)=="aloe": info.use="aloe"
		if herb.kind(id)=="sap": info.use="ironwood_sap"
		return info
	if not id is String: return {}
	if FIXED.has(id): return FIXED[id]
	if id == L8_SHAMAN_KEY: return {"slot":"","label":"Dracoid Sigil","icon":Definitions.icon(102),"origin":"jungle","definition":102}
	if id in MuseumAloe.IDS: return {"slot":"","label":Definitions.label(110),"icon":Definitions.icon(110),"origin":"museum","definition":110,"use":"aloe"}
	if id in MuseumScrolls.IDS:
		var scroll_index: int = MuseumScrolls.DEFINITIONS[MuseumScrolls.IDS.find(id)]
		return {"slot":"","label":Definitions.label(scroll_index),"icon":Definitions.icon(scroll_index),"origin":"museum","definition":scroll_index}
	# Hive original rows 5-9 (hive_world_items_state.gd): carried only, no item use hosted; Jungle scope like Hive wax.
	if HiveItems.valid(id):
		var hive_index := HiveItems.definition(id)
		return {"slot":"","label":Definitions.label(hive_index),"icon":Definitions.icon(hive_index),"origin":"jungle","definition":hive_index}
	# Museum / Dark Halls / Savage Jungle original rows (area_world_items_state.gd): carried, slot from the definition's class
	# (the defense byte through item_defense_data.gd for the equippable ones), no item use hosted here (item_handlers.gd routes).
	if AreaItems.valid(id):
		var area_index := AreaItems.definition(id)
		return {"slot":Definitions.slot(area_index),"label":Definitions.label(area_index),"icon":Definitions.icon(area_index),"origin":AreaItems.origin(id),"definition":area_index}
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
	# Renewable plant/tree pools (jungle_harvest_items.gd): "107-Aloe" (handler9, the same fixed +5 pending heal as
	# "108-Cave aloe") and "109-Ironwod sap" (handler98).
	if Harvest.valid(id):
		var info := Harvest.info(id)
		return {"slot":"","label":str(info.label),"icon":str(info.icon),"origin":"jungle","use":"aloe" if Harvest.kind(id) == "aloe" else "ironwood_sap"}
	# Renewable Hive Amber pool (hive_amber_items.gd): original "110-Amber" (handler0, no use).
	if Amber.valid(id): return {"slot":"","label":"Amber","icon":Amber.ICON,"origin":"jungle"}
	# Dark Halls control grants (dark_halls_items.gd).
	if DarkHalls.valid(id): return DarkHalls.entry(id)
	if Runes.valid(id): return {"slot":"","label":"Wax runes","icon":GENERATED+"hive_wax_runes/runes.png","origin":"jungle"}
	# Power Orb, magic-shop and jungle world items share the existing shop presentation.
	if id == Monastery.ORB or id in MagicShop.all_item_ids() or WorldItems.valid(id):
		var info: Dictionary = ShopItems.info(id)
		var result := {"slot":"weapon" if id in MAGIC_WEAPONS else "","label":str(info.label),"icon":str(info.icon),"origin":"jungle"}
		# Original Jungle row15 is the same definition37 shield as Cave guard52/53 loot.
		if WorldItems.valid(id) and WorldItems.source_name(id) == "38-Guard shield": result.slot = "offhand"
		if MagicShop.source_name(id) == "131-Mana foil": result.use = "mana_foil"
		# Jungle rows63-67 are the cave Aloe's own definition110/identity3732130108/handler9.
		if WorldItems.valid(id) and WorldItems.source_name(id) == ALOE_SOURCE_NAME: result.use = "aloe"
		# Definition111/handler98 consumes the held sap without a stat effect.
		if WorldItems.valid(id) and WorldItems.source_name(id) == "109-Ironwod sap": result.use = "ironwood_sap"
		# Magic-shop "57a-Fire crstl" (definition57/handler2): charges spent per use; burns out to "57b-Fire brnt".
		if MagicShop.source_name(id) == "57a-Fire crstl" or (WorldItems.valid(id) and WorldItems.source_name(id) == "57a-Fire crstl"): result.use = "fire_crystal"
		# River-dam burrow rows69-71: the same definition68/handler6 Ancients stone as the Cave/Hive stones.
		if WorldItems.valid(id) and WorldItems.source_name(id) == "66-Ancients stn": result.use = "ancient"
		# Rows54-57: definition84/handler20 consumes the held fruit and clears player status +1B5 (no heal/bonus).
		if WorldItems.valid(id) and WorldItems.source_name(id) == "82-Vels fruit": result.use = "vels_fruit"
		return result
	# Thieves' Den grants "123-Pois paint" and "93-Skull key" (thieves_den_state.ITEMS; Firestorm reuses the shop id):
	# carried only, original icons from the staged definitions (docs/thieves-den.md).
	if id in ThievesDen.all_item_ids() and ThievesDen.source_name(id) != "9-Firestorm" and Definitions.ready():
		var den_index := Definitions.by_name(ThievesDen.source_name(id))
		if den_index >= 0:
			var den_entry := {"slot":"","label":Definitions.label(den_index),"icon":Definitions.icon(den_index),"origin":"jungle","definition":den_index}
			# "123-Pois paint" (handler 10): applied to the weapon (weapon_poison.gd).
			if ThievesDen.source_name(id) == "123-Pois paint": den_entry.use = "poison_paint"
			return den_entry
	var index := generic_index(id)
	if index >= 0:
		var result := {"slot":"" if Act2Items.valid(id) else Definitions.slot(index),"label":Definitions.label(index),"icon":Definitions.icon(index),"origin":"world","definition":index}
		if index == 117: result.use = "silverleaf" # Brady printed41: +5 Magic Points.
		if index == 119: result.use = "amaranth_serum" # Brady printed42: no effect alone; handler98 consumes.
		return result
	return {}

## Definition index of a generic "item:defNNN" id, or -1 (unknown, malformed or a ghost row).
static func generic_index(id: Variant) -> int:
	if preload("res://scripts/lol2/l8_herbalist.gd").valid(id): return preload("res://scripts/lol2/l8_herbalist.gd").definition(id)
	if id is String and id.begins_with("act2:"): return Act2Items.definition(id)
	if not id is String or not id.begins_with(GENERIC_PREFIX): return -1
	var digits: String = id.trim_prefix(GENERIC_PREFIX)
	if digits.length() != 3 or not digits.is_valid_int(): return -1
	var index := int(digits)
	return index if Definitions.ready() and Definitions.carriable(index) else -1

static func generic_id(index: int) -> String: return GENERIC_PREFIX + "%03d" % index

## Original definition name behind any carried identity ("" when the port has no source definition for it).
static func definition_name(id: Variant) -> String:
	if not id is String: return ""
	if FIXED_NAMES.has(id): return FIXED_NAMES[id]
	if id in MuseumAloe.IDS: return Definitions.name(110)
	if id in MuseumScrolls.IDS: return Definitions.name(MuseumScrolls.DEFINITIONS[MuseumScrolls.IDS.find(id)])
	if HiveItems.valid(id): return HiveItems.source_name(id)
	if AreaItems.valid(id): return AreaItems.source_name(id)
	if id == Captain.SWORD: return "5-Short swd"
	if id == Captain.ARMOR: return "37-Brnt Chain"
	if Stalagmite.valid_item(id): return "1-Stalagmite"
	if Aloe.valid_item(id): return ALOE_SOURCE_NAME
	for source in WeaponShop.ITEMS:
		if WeaponShop.ITEMS[source] == id: return source
	if id == Monastery.FLUTE: return "94-Iron flute"
	if id == Monastery.ORB: return "83-Power orb"
	if id == KITYARA_KNIFE: return "30-Empty hand"
	if id == L8_SHAMAN_KEY: return "100-Drac sigil"
	if id == Wax.ITEM or BeeWax.valid(id): return "71-Wax"
	if Harvest.valid(id): return "107-Aloe" if Harvest.kind(id) == "aloe" else "109-Ironwod sap"
	if Amber.valid(id): return "110-Amber"
	if DarkHalls.valid(id): return str(DarkHalls.ITEMS[id].name)
	if Runes.valid(id): return "72-Wax runes"
	if id in MagicShop.all_item_ids(): return MagicShop.source_name(id)
	if WorldItems.valid(id): return WorldItems.source_name(id)
	if id in ThievesDen.all_item_ids(): return ThievesDen.source_name(id)
	var index := generic_index(id)
	return Definitions.name(index) if index >= 0 else ""

## Definition index (0..169) behind any carried identity, or -1.
static func definition(id: Variant) -> int:
	var index := generic_index(id)
	return index if index >= 0 else Definitions.by_name(definition_name(id))

## Shown when an item has no traced use and is not equipment.
static func use_hint(id: Variant) -> String:
	if use_kind(id) != "" or slot(id) != "": return ""
	return "No inventory use is known for this item yet." if definition(id) >= 0 else "This item has not been identified."

static func known(id: Variant) -> bool: return not entry(id).is_empty()
static func slot(id: Variant) -> String: return str(entry(id).get("slot",""))
static func label(id: Variant) -> String: return str(entry(id).get("label",""))
## Ground sprite: the picture of the item lying in the world (world billboards).
static func icon(id: Variant) -> String: return str(entry(id).get("icon",""))
## Inventory picture: the original 24x24 icon of the identity's definition; falls back to the ground sprite only
## when the identity has no definition ("draracle/prop/1108/sample") or the icons are not staged.
static func inventory_icon(id: Variant) -> String:
	var path := Definitions.inventory_icon(definition(id)) if Definitions.ready() else ""
	return path if not path.is_empty() else icon(id)
static func defense(id: Variant) -> int:
	if generic_index(id) >= 0: return Definitions.defense(generic_index(id))
	return int(Defenses.ITEMS.get(id,{}).get("defense",0)) if id is String else 0
static func mitigation(id: Variant) -> Array:
	return Defenses.ITEMS.get(id,{}).get("descriptors",[]).duplicate(true) if id is String else []
## Implemented inventory use; empty means no verified use.
static func use_kind(id: Variant) -> String: return str(entry(id).get("use",""))
## Every identity with an implemented use; bounds the saved consumed-item history.
static func consumables() -> Array: return ids("jungle").filter(func(id): return use_kind(id) != "") + [generic_id(117),generic_id(119)]

## Known and obtainable no later than `scope` (cave < museum < jungle).
static func admitted(id: Variant, scope: String) -> bool:
	var e := entry(id)
	return not e.is_empty() and scope in SCOPES and SCOPES.find(str(e.origin)) <= SCOPES.find(scope)

## Every identity a scope admits; finite by construction.
static func ids(scope: String = "jungle") -> Array:
	var all: Array = FIXED.keys() + [Captain.SWORD,Captain.ARMOR] + MuseumScrolls.IDS + MuseumAloe.IDS + HiveItems.IDS + AreaItems.all_ids()
	for record in Stalagmite.RECORDS: all.append(Stalagmite.item_id(record,1))
	for record in Aloe.RECORDS:
		for harvest in range(1,4): all.append(Aloe.item_id(record,harvest))
	all += WeaponShop.ITEMS.values().filter(func(id): return id not in FIXED)
	all += preload("res://scripts/lol2/l8_herbalist.gd").ids()
	all += [Monastery.FLUTE,Monastery.ORB,Wax.ITEM,KITYARA_KNIFE,L8_SHAMAN_KEY] + MagicShop.all_item_ids() + WorldItems.ITEMS.keys() + BeeWax.POOL + Harvest.all() + Amber.pool() + DarkHalls.ITEMS.keys()
	for index in range(23): all.append(Runes.PREFIX+str(index))
	all += ThievesDen.all_item_ids().filter(func(id): return id not in all)
	if scope == "world" and Definitions.ready():
		for index in Definitions.COUNT:
			if Definitions.carriable(index): all.append(generic_id(index))
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
