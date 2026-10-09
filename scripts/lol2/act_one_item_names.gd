extends RefCounted
## Stable carried IDs mapped to the names compared by original room DLLs.
static func source_name(id: String) -> String:
	for mapping in [preload("res://scripts/lol2/monastery_conversation.gd").SOURCE_ITEMS,preload("res://scripts/lol2/weapon_shop_state.gd").ITEMS]:
		for name in mapping:
			if mapping[name]==id: return name
	var magic := preload("res://scripts/lol2/magic_shop_state.gd").source_name(id)
	if not magic.is_empty(): return magic
	if id=="museum:control181:Tho_Broken": return "12-Tho Broken"
	if id=="museum:control87:Sk_key": return "92-Sk key"
	if id=="museum:movable55:SS1": return "68-SS1"
	if id in preload("res://scripts/lol2/dragon_blood_state.gd").ITEMS:return "Drag Blood"
	if id=="jungle:kelsrick:Fine_Longsword": return "6-Fine longswd"
	if id=="museum:prop153:Long_arm": return "7-Long arm"
	if id=="jungle:item51:Th_Dagger": return "10-Th Dagger"
	if preload("res://scripts/lol2/jungle_beehive_wax.gd").valid(id): return "71-Wax"
	if preload("res://scripts/lol2/jungle_world_items_catalog.gd").valid(id): return preload("res://scripts/lol2/jungle_world_items_catalog.gd").source_name(id)
	return id
