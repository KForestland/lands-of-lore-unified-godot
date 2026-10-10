extends RefCounted
## Stable ids of the admitted Huline Jungle world-item rows (tools/prepare_jungle_world_items.py, items.json).
## Generated from the pinned catalog; row51 (dagger) stays with jungle_source_pickups.gd.
const ITEMS:={
	"jungle:item0:Snare":{"row":0,"name":"27-Snare","label":"Snare","icon":"res://assets/lol2/generated/jungle_world_items/item0_snare.png"},
	"jungle:item50:Wax":{"row":50,"name":"71-Wax","label":"Wax","icon":"res://assets/lol2/generated/jungle_world_items/item50_wax.png"},
	"jungle:item52:Ironwod_sap":{"row":52,"name":"109-Ironwod sap","label":"Ironwod sap","icon":"res://assets/lol2/generated/jungle_world_items/item52_ironwod_sap.png"},
	"jungle:item53:Ironwod_sap":{"row":53,"name":"109-Ironwod sap","label":"Ironwod sap","icon":"res://assets/lol2/generated/jungle_world_items/item53_ironwod_sap.png"},
	"jungle:item54:Vels_fruit":{"row":54,"name":"82-Vels fruit","label":"Vels fruit","icon":"res://assets/lol2/generated/jungle_world_items/item54_vels_fruit.png"},
	"jungle:item55:Vels_fruit":{"row":55,"name":"82-Vels fruit","label":"Vels fruit","icon":"res://assets/lol2/generated/jungle_world_items/item55_vels_fruit.png"},
	"jungle:item56:Vels_fruit":{"row":56,"name":"82-Vels fruit","label":"Vels fruit","icon":"res://assets/lol2/generated/jungle_world_items/item56_vels_fruit.png"},
	"jungle:item57:Vels_fruit":{"row":57,"name":"82-Vels fruit","label":"Vels fruit","icon":"res://assets/lol2/generated/jungle_world_items/item57_vels_fruit.png"},
	"jungle:item63:Cave_aloe":{"row":63,"name":"108-Cave aloe","label":"Cave aloe","icon":"res://assets/lol2/generated/jungle_world_items/item63_cave_aloe.png"},
	"jungle:item64:Cave_aloe":{"row":64,"name":"108-Cave aloe","label":"Cave aloe","icon":"res://assets/lol2/generated/jungle_world_items/item64_cave_aloe.png"},
	"jungle:item65:Cave_aloe":{"row":65,"name":"108-Cave aloe","label":"Cave aloe","icon":"res://assets/lol2/generated/jungle_world_items/item65_cave_aloe.png"},
	"jungle:item66:Cave_aloe":{"row":66,"name":"108-Cave aloe","label":"Cave aloe","icon":"res://assets/lol2/generated/jungle_world_items/item66_cave_aloe.png"},
	"jungle:item67:Cave_aloe":{"row":67,"name":"108-Cave aloe","label":"Cave aloe","icon":"res://assets/lol2/generated/jungle_world_items/item67_cave_aloe.png"}}
static func valid(id: Variant) -> bool: return id is String and ITEMS.has(id)
static func info(id: String) -> Dictionary:
	return {"label":ITEMS[id].label,"icon":ITEMS[id].icon} if ITEMS.has(id) else {}
static func source_name(id: String) -> String: return str(ITEMS[id].name) if ITEMS.has(id) else ""
static func rows() -> Array: return ITEMS.values().map(func(v):return int(v.row))
static func id_of(row: int) -> String:
	for id in ITEMS:
		if int(ITEMS[id].row)==row: return id
	return ""
