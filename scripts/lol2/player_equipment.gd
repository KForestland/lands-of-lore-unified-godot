extends RefCounted
## Known playable weapon identities; damage still uses the shared provisional melee adapter.
const EXTRA_WEAPONS := ["jungle:item51:Th_Dagger","jungle:magic_shop:Dag_Light","jungle:magic_shop:Tho_fixed"]
const SHOP_WEAPONS := ["jungle:weapon_shop:Short_Sword","jungle:weapon_shop:Long_Arm","jungle:weapon_shop:Firestorm"]
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
static func armor(id: String) -> bool:
	return Catalog.slot(id) == "armor"
static func armor_label(id: String) -> String:
	return "None" if id.is_empty() else Catalog.label(id) if armor(id) else "Mail Shirt"
static func offhand(id: String) -> bool:
	return Catalog.slot(id) == "offhand"
static func weapon(id: String) -> bool:
	return Catalog.slot(id) == "weapon"
static func label(id: String) -> String:
	if id.is_empty(): return "Unarmed"
	return Catalog.label(id) if weapon(id) or id == preload("res://scripts/lol2/cave_captain_items.gd").ARMOR else "Fine Longsword"
static func icon(id: String) -> String:
	return Catalog.icon(id) if weapon(id) or id == preload("res://scripts/lol2/cave_captain_items.gd").ARMOR else Catalog.icon("museum:item11:Fine_Longsword")
## HUD weapon ring picture: the inventory icon of the same identity icon() resolves.
static func inventory_icon(id: String) -> String:
	return Catalog.inventory_icon(id) if weapon(id) or id == preload("res://scripts/lol2/cave_captain_items.gd").ARMOR else Catalog.inventory_icon("museum:item11:Fine_Longsword")
