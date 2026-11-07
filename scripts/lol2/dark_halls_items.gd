extends RefCounted
## Dark Halls item grants (tools/prepare_dark_halls_loot.py -> scripts/lol2/dark_halls_loot_source.json): one id per
## control use. Labels are the full original names; the bracers and shield take the modern offhand slot (as the shop
## Gargoyle Bracers); the Ancients stone shares the cave/Hive stone use. Pinned against the source by dark_halls_loot_test.
const ITEMS := {
	"darkhalls:actor57:Plasma_staff":{"label":"Plasma staff","icon":"res://assets/lol2/generated/dark_halls_loot/plasma_staff.png","slot":"weapon","name":"14-Plasma staff"},
	"darkhalls:control58u1:Stone_bracrs":{"label":"Stone bracers","icon":"res://assets/lol2/generated/dark_halls_loot/stone_bracrs.png","slot":"offhand","name":"47-Stone bracrs"},
	"darkhalls:control59u1:Fire_shield":{"label":"Fire shield","icon":"res://assets/lol2/generated/dark_halls_loot/fire_shield.png","slot":"offhand","name":"45-Fire shield"},
	"darkhalls:control71u1:Colims_amult":{"label":"Colim's amulet","icon":"res://assets/lol2/generated/dark_halls_loot/colims_amult.png","slot":"","name":"85-Colims amult"},
	"darkhalls:control968u1:HlScrl":{"label":"Healing scroll","icon":"res://assets/lol2/generated/dark_halls_loot/hlscrl.png","slot":"","name":"146-HlScrl"},
	"darkhalls:control968u2:HlScrl":{"label":"Healing scroll","icon":"res://assets/lol2/generated/dark_halls_loot/hlscrl.png","slot":"","name":"146-HlScrl"},
	"darkhalls:control971u1:Prsmscrl":{"label":"Prism scroll","icon":"res://assets/lol2/generated/dark_halls_loot/prsmscrl.png","slot":"","name":"149-Prsmscrl"},
	"darkhalls:control974u1:Ancients_stn":{"label":"Ancients’ Stone","icon":"res://assets/lol2/generated/dark_halls_loot/ancients_stn.png","slot":"","name":"66-Ancients stn","use":"ancient"},
	"darkhalls:control974u2:Spkscrl":{"label":"Spark scroll","icon":"res://assets/lol2/generated/dark_halls_loot/spkscrl.png","slot":"","name":"73-Spkscrl"},
	"darkhalls:control975u1:Prsmscrl":{"label":"Prism scroll","icon":"res://assets/lol2/generated/dark_halls_loot/prsmscrl.png","slot":"","name":"149-Prsmscrl"},
	"darkhalls:control975u2:Prsmscrl":{"label":"Prism scroll","icon":"res://assets/lol2/generated/dark_halls_loot/prsmscrl.png","slot":"","name":"149-Prsmscrl"},
	"darkhalls:control976u1:HlScrl":{"label":"Healing scroll","icon":"res://assets/lol2/generated/dark_halls_loot/hlscrl.png","slot":"","name":"146-HlScrl"},
	"darkhalls:control976u2:SumScrl":{"label":"Summon scroll","icon":"res://assets/lol2/generated/dark_halls_loot/sumscrl.png","slot":"","name":"147-SumScrl"}}
static func valid(id: Variant) -> bool: return id is String and ITEMS.has(id)
static func entry(id: String) -> Dictionary:
	var e: Dictionary = ITEMS[id]
	var result := {"slot":str(e.slot),"label":str(e.label),"icon":str(e.icon),"origin":"jungle"}
	if e.has("use"): result.use = str(e.use)
	return result
