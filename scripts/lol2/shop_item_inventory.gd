extends RefCounted
## Inventory presentation for the original MAGIC room grants.
const LABELS := {"War_cluster":"War Cluster","Mana_foil":"Mana Foil","SS5":"Spell Scroll","Fire_crystals":"Fire Crystal","Dag_Light":"Dagger of Light","Tho_fixed":"Thohan's Great Sword"}
static func info(id: String) -> Dictionary:
	if id == "museum:control181:Tho_Broken": return {"label":"Broken Thohan","icon":"res://assets/lol2/generated/museum_broken_thohan/icon.png"}
	if id == "museum:control87:Sk_key": return {"label":"Sk key","icon":"res://assets/lol2/generated/museum_key_locks/sk_key.png"}
	if id == "museum:prop153:Long_arm": return {"label":"Long arm","icon":"res://assets/lol2/generated/museum_long_arm/icon.png"}
	if id == "museum:movable55:SS1": return {"label":"SS1","icon":"res://assets/lol2/generated/museum_key_locks/ss1.png"}
	if id == "monastery:item70:Dampen_charm": return {"label":"Dampen charm","icon":"res://assets/lol2/generated/monastery_dampen/dampen.png"}
	if id == "monastery:item83:Power_Orb": return {"label":"Power Orb","icon":"res://assets/lol2/generated/monastery_moff/Power_Orb.png"}
	if preload("res://scripts/lol2/jungle_beehive_wax.gd").valid(id): return {"label":"Wax","icon":preload("res://scripts/lol2/jungle_beehive_wax.gd").ICON}
	if preload("res://scripts/lol2/jungle_harvest_items.gd").valid(id): return preload("res://scripts/lol2/jungle_harvest_items.gd").info(id)
	if id == "hive:control121:Reaver_of_GO": return {"label":"Reaver of GO","icon":"res://assets/lol2/generated/hive_reaver_amber/reaver.png"}
	if preload("res://scripts/lol2/hive_amber_items.gd").valid(id): return {"label":"Amber","icon":preload("res://scripts/lol2/hive_amber_items.gd").ICON}
	if id == "hive:prop214:Net_of_Exile": return {"label":"Net of Exile","icon":"res://assets/lol2/generated/hive_net_exile/net.png"}
	if id == "cave:prop1050:Ancients_Stone": return {"label":"Ancients’ Stone","icon":"res://assets/lol2/generated/cave_stone_manafoil/stone_icon.png"}
	if id == "cave:control75:Mana_foil": return {"label":"Mana Foil","icon":"res://assets/lol2/generated/cave_stone_manafoil/foil_icon.png"}
	if id == "jungle:item51:Th_Dagger": return {"label":"Th Dagger","icon":"res://assets/lol2/generated/jungle_source_pickups/th_dagger.png"}
	if preload("res://scripts/lol2/jungle_world_items_catalog.gd").valid(id): return preload("res://scripts/lol2/jungle_world_items_catalog.gd").info(id)
	if id not in preload("res://scripts/lol2/magic_shop_state.gd").all_item_ids(): return {}
	var key := id.get_slice(":",2)
	if key.begins_with("Fire_crystals_"): key = "Fire_crystals"
	return {"label":LABELS[key],"icon":"res://assets/lol2/generated/magic_shop_items/"+key+".png"}
