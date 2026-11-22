extends RefCounted
## Binding fixture: source class-to-slot contract plus approved WO3/WO4 uses.
## This is deliberately independent of Catalog.use_kind/slot and food modules.
const USES:={6:"physical_throw",9:"physical_throw",23:"physical_throw",68:"ancient",72:"dampen_charm",75:"stored_spell",84:"vels_fruit",109:"aloe",110:"aloe",111:"ironwood_sap",114:"lamplight_eggs",117:"silverleaf",119:"amaranth_serum",122:"black_lichen",123:"champion_stone",125:"poison_paint",127:"ancient",133:"mana_foil",116:"gorgonite",118:"mandrake",124:"inert_food",129:"death_sac",134:"mind_cluster",126:"war_cluster",148:"stored_spell",149:"stored_spell",150:"stored_spell",151:"stored_spell"}
static func use_kind(definition:int)->String:return str(USES.get(definition,""))
static func slot(definition:int,item_class:int)->String:
 if definition==48:return "armor" # Owner-approved circlet/body-armor exclusivity.
 return str({0x43:"accessory",0x44:"weapon",0x48:"weapon",0x50:"offhand",0x53:"offhand",0x60:"armor"}.get(item_class,""))
